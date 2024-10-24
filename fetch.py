import json
import subprocess
import re
import hashlib
import os
import argparse

# Set up argument parser
parser = argparse.ArgumentParser(description="Fetch and parse system configuration.")
parser.add_argument("--debug", action="store_true", help="Enable debug output")
args = parser.parse_args()

def debug_print(message):
    """Print debug information if debug mode is enabled."""
    if args.debug:
        print(message)

def execute_command(command):
    """Execute a shell command and return the output."""
    debug_print(f"Executing command: {command}")
    result = subprocess.run(command, capture_output=True, text=True, shell=True)
    debug_print(f"Command output: {result.stdout.strip()}")
    return result.stdout.strip()

def parse_grep_listen_addresses(output, data_type=None):
    """Parse the output of the grep command for listen addresses."""
    config = {}
    for line in output.split("\n"):
        if line:
            key, value = line.split(":", 1)
            config[key.strip()] = value.strip()
    debug_print(f"Parsed listen addresses: {config}")
    return config

def parse_node_info(output, data_type=None):
    """Parse the output of the node-info command."""
    config = {}
    for line in output.split("\n"):
        if line:
            if ':' in line:
                key, value = line.split(":", 1)
                key = f"node_info_{key.strip().lower().replace(' ', '_')}"
                value = value.strip().replace(" QUIL", "")
                if data_type and key in data_type:
                    value = data_type[key](value)
                config[key] = value
            else:
                config[f"node_info_{line.strip().lower().replace(' ', '_')}"] = ""
    debug_print(f"Parsed node info: {config}")
    return config

def parse_json_output(output, data_type=None):
    """Parse the JSON output from the recalibrating difficulty metric command."""
    try:
        parsed_output = output and json.loads(output) or {}
        debug_print(f"Parsed JSON output: {parsed_output}")
        return parsed_output
    except json.JSONDecodeError:
        debug_print("Failed to parse JSON output.")
        return {}

def parse_system_uptime(output, data_type=None):
    """Parse the system uptime to get hours and load average."""
    uptime_match = re.search(r'up\s+((\d+)\s+days,)?\s*(\d+):(\d+)', output)
    load_average_match = re.search(r'load average:\s+([\d.]+)', output)

    hours = 0
    if uptime_match:
        days = int(uptime_match.group(2) or 0)
        hours = days * 24 + int(uptime_match.group(3))

    load_average = load_average_match.group(1) if load_average_match else "0.0"
    
    parsed_output = {"uptime": hours, "load": float(load_average)}
    debug_print(f"Parsed system uptime: {parsed_output}")
    return parsed_output

def parse_disk_usage(output, data_type=None):
    """Parse the disk usage to get the usage percentage of the main partition."""
    usage_match = re.search(r'(\d+)%', output)
    parsed_output = {"disk_usage": int(usage_match.group(1))} if usage_match else {"disk_usage": 0}
    debug_print(f"Parsed disk usage: {parsed_output}")
    return parsed_output

def verify_sha3_256_checksum(directory):
    """Verify the SHA3-256 checksum of the binary file in the specified directory."""
    debug_print(f"Verifying SHA3-256 checksum in directory: {directory}")
    files = sorted([f for f in os.listdir(directory) if f.endswith('-linux-amd64')])
    if not files:
        debug_print("No binary files found.")
        return "No binary files found."
    
    file_path = os.path.join(directory, files[-1])
    digest_file_path = file_path + '.dgst'

    with open(digest_file_path, 'r') as dgst_file:
        for line in dgst_file:
            if line.startswith(f"SHA3-256({os.path.basename(file_path)})"):
                expected_hash = line.split('= ')[1].strip()
                break
        else:
            debug_print("No matching hash found in the digest file.")
            return "No matching hash found in the digest file."

    with open(file_path, 'rb') as f:
        file_data = f.read()
        actual_hash = hashlib.sha3_256(file_data).hexdigest()

    if expected_hash == actual_hash:
        debug_print("sha3-256 ok")
        return "sha3-256 ok"
    else:
        debug_print("sha3-256 failed")
        return "sha3-256 failed"

def parse_proof_details(output, data_type=None):
    """Parse the log entry for the increment and time_taken."""
    increment_match = re.search(r'"increment":(\d+)', output)
    time_taken_match = re.search(r'"time_taken":([\d.]+)', output)
    ts_proof_match = re.search(r'"ts":([\d.]+)', output)
    
    parsed_output = {
        "proof_increment": int(increment_match.group(1)) if increment_match else 0,
        "proof_time": float(time_taken_match.group(1)) if time_taken_match else 0.0,
        "ts_proof": float(ts_proof_match.group(1)) if ts_proof_match else 0.0
    }
    debug_print(f"Parsed proof details: {parsed_output}")
    return parsed_output

def get_config(commands):
    """Execute a list of commands and return their results as a JSON object."""
    config = {}

    for cmd in commands:
        command = cmd['command']
        key = cmd['key']
        parser = cmd.get('parser', lambda x, y: x)  # Use the parser if provided, otherwise pass through
        data_type = cmd.get('data_type', None)
        update_dict = cmd.get('update_dict', False)
        if callable(command):
            result = command()
        else:
            result = execute_command(command)
        parsed_result = parser(result, data_type)
        
        if update_dict and isinstance(parsed_result, dict):
            config.update(parsed_result)
        else:
            config[key] = parsed_result

    # Overwrite node_info_max_frame with leader_frame
    if 'leader_frame' in config and config['leader_frame'] is not None:
        config['node_info_max_frame'] = config['leader_frame']

    # Check if there are multiple entries of the return leader frame entry with the same frame_number as node_info_max_frame
    if 'node_info_max_frame' in config:
        max_frame = config['node_info_max_frame']
        debug_print(f"Checking for stuck frame. Max frame: {max_frame}")
        check_command = f"grep -a '\"returning leader frame\".*\"frame_number\":{max_frame}' /var/log/syslog"
        frame_entries = execute_command(check_command).split('\n')
        same_frame_count = len([entry for entry in frame_entries if entry.strip()])
        debug_print(f"Number of entries with the same frame: {same_frame_count}")
        
        if same_frame_count >= 10:
            config['stuck_on_frame'] = True
            config['stuck_frame_count'] = same_frame_count
            debug_print(f"Node appears to be stuck. Frame count: {same_frame_count}")
            
            # Extract the "ts" value from the first and last log entries
            try:
                debug_print(frame_entries)
                try:
                    first_ts = json.loads('{' + frame_entries[0].split('{', 1)[1])["ts"]
                    last_ts = json.loads('{' + frame_entries[-1].split('{', 1)[1])["ts"]
                    debug_print(f"First timestamp: {first_ts}, Last timestamp: {last_ts}")
                except (IndexError, KeyError, json.JSONDecodeError) as e:
                    debug_print(f"Error processing frame entries: {e}")
                    first_ts = last_ts = None
                
                # Calculate the time the node has been stuck
                stuck_duration = last_ts - first_ts
                
                config['stuck_since'] = first_ts
                minutes, seconds = divmod(stuck_duration, 60)
                config['stuck_duration'] = f"{int(minutes)} minutes and {int(seconds)} seconds"
                debug_print(f"Stuck duration: {stuck_duration} seconds")
            except (IndexError, KeyError, json.JSONDecodeError) as e:
                debug_print(f"Error processing frame entries: {e}")
                config['stuck_since'] = None
                config['stuck_duration_seconds'] = None
            
        else:
            config['stuck_on_frame'] = False
            debug_print("Node does not appear to be stuck")

    json_output = json.dumps(config, indent=2)
    debug_print("Final config:")
    debug_print(json_output)
    print(json_output)
    
    return json_output

commands = [
    {"command": "grep -a '\"checking peer list\"' /var/log/syslog | tail -n 1 | sed -E 's/.*\"current_head_frame\":([0-9]+).*/\\1/'", "key": "leader_frame", "parser": lambda x, y: int(x) if x.isdigit() else None},
    {"command": "grep -E 'listen(Multiaddr|GrpcMultiaddr)' /root/ceremonyclient/node/.config/config.yml", "key": "listen_addresses", "parser": parse_grep_listen_addresses, "update_dict": True},
    {"command": "nproc", "key": "cpu_count", "parser": lambda x, y: int(x) if x.isdigit() else 0},
    {"command": "uptime", "key": "system_uptime", "parser": parse_system_uptime, "update_dict": True},
    {"command": "cd /root/ceremonyclient/node/ && git rev-parse --abbrev-ref --short HEAD", "key": "git_branch"},
    {"command": "cd /root/ceremonyclient/node/ && git rev-parse --short HEAD", "key": "git_commit_hash"},
    {"command": lambda: verify_sha3_256_checksum("/root/ceremonyclient/node"), "key": "bin_checksum"},
    {"command": "grep -A 10 '\\[Service\\]' /lib/systemd/system/ceremonyclient.service | grep 'Environment=GOMAXPROCS=' | sed 's/.*Environment=GOMAXPROCS=//'", "key": "maxprocs", "parser": lambda x, y: int(x) if x.isdigit() else 0},
    {"command": "grep -a 'recalibrating difficulty metric' /var/log/syslog | tail -n 1 | sed 's/^[^{]*//g' | jq '. | {ts: .ts, next_difficulty_metric: .next_difficulty_metric}'", "key": "difficulty_metric", "parser": parse_json_output, "update_dict": True},
    {"command": "df / | grep / | awk '{print $5}'", "key": "disk_usage", "parser": parse_disk_usage, "update_dict": True},
    {"command": "grep -a '\"completed duration proof\"' /var/log/syslog | tail -n 1", "key": "proof_details", "parser": parse_proof_details, "update_dict": True},
]

def get_latest_binary_command(command_template):
    files = sorted([f for f in os.listdir("/root/ceremonyclient/node/") if f.endswith('-linux-amd64')])
    if files:
        latest_binary = files[-1]
        return command_template.format(binary=latest_binary), latest_binary
    else:
        return None, None

node_info_command_template = "cd /root/ceremonyclient/node/ && /root/ceremonyclient/node/{binary} -node-info"
latest_node_info_command, latest_binary = get_latest_binary_command(node_info_command_template)

if latest_node_info_command:
    commands.append({"command": latest_node_info_command, "key": "node_info", "parser": parse_node_info, "data_type": {"node_info_owned_balance": float, "node_info_unconfirmed_balance": float}, "update_dict": True})

initial_config = {}
for cmd in commands:
    command = cmd['command']
    key = cmd['key']
    parser = cmd.get('parser', lambda x, y: x)
    data_type = cmd.get('data_type', None)
    update_dict = cmd.get('update_dict', False)
    if callable(command):
        result = command()
    else:
        result = execute_command(command)
    parsed_result = parser(result, data_type)
    
    if update_dict and isinstance(parsed_result, dict):
        initial_config.update(parsed_result)
    else:
        initial_config[key] = parsed_result

get_config(commands)
