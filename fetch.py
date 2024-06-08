import json
import subprocess
import re
import hashlib
import os

def execute_command(command):
    """Execute a shell command and return the output."""
    result = subprocess.run(command, capture_output=True, text=True, shell=True)
    return result.stdout.strip()

def parse_grep_listen_addresses(output, data_type=None):
    """Parse the output of the grep command for listen addresses."""
    config = {}
    for line in output.split("\n"):
        if line:
            key, value = line.split(":", 1)
            config[key.strip()] = value.strip()
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
    return config

def parse_json_output(output, data_type=None):
    """Parse the JSON output from the recalibrating difficulty metric command."""
    try:
        return output and json.loads(output) or {}
    except json.JSONDecodeError:
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
    
    return {"uptime": hours, "load": float(load_average)}

def parse_disk_usage(output, data_type=None):
    """Parse the disk usage to get the usage percentage of the main partition."""
    usage_match = re.search(r'(\d+)%', output)
    return {"disk_usage": int(usage_match.group(1))} if usage_match else {"disk_usage": 0}

def verify_sha3_256_checksum(directory):
    """Verify the SHA3-256 checksum of the binary file in the specified directory."""
    # Find the binary file matching the pattern
    files = sorted([f for f in os.listdir(directory) if f.endswith('-linux-amd64')])
    if not files:
        return "No binary files found."
    
    file_path = os.path.join(directory, files[-1])
    digest_file_path = file_path + '.dgst'

    # Extract the expected hash from the digest file
    with open(digest_file_path, 'r') as dgst_file:
        for line in dgst_file:
            if line.startswith(f"SHA3-256({os.path.basename(file_path)})"):
                expected_hash = line.split('= ')[1].strip()
                break
        else:
            return "No matching hash found in the digest file."

    # Calculate the actual hash of the file using hashlib
    with open(file_path, 'rb') as f:
        file_data = f.read()
        actual_hash = hashlib.sha3_256(file_data).hexdigest()

    # Compare the expected and actual hashes and return the result
    if expected_hash == actual_hash:
        return "sha3-256 ok"
    else:
        return "sha3-256 failed"

def parse_proof_details(output, data_type=None):
    """Parse the log entry for the increment and time_taken."""
    increment_match = re.search(r'"increment":(\d+)', output)
    time_taken_match = re.search(r'"time_taken":([\d.]+)', output)
    ts_proof_match = re.search(r'"ts":([\d.]+)', output)
    
    return {
        "proof_increment": int(increment_match.group(1)) if increment_match else 0,
        "proof_time": float(time_taken_match.group(1)) if time_taken_match else 0.0,
        "ts_proof": float(ts_proof_match.group(1)) if ts_proof_match else 0.0
    }

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

    # Convert the dictionary to a JSON object
    json_output = json.dumps(config, indent=2)
    
    # Print the JSON object
    print(json_output)

# Initial list of commands to execute with specified keys, optional parser functions, data types, and update_dict flag
commands = [
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

# Find the latest version dynamically
def get_latest_binary_command(command_template):
    files = sorted([f for f in os.listdir("/root/ceremonyclient/node/") if f.endswith('-linux-amd64')])
    if files:
        latest_binary = files[-1]
        return command_template.format(binary=latest_binary), latest_binary
    else:
        return None, None

# Command to get node info using the latest binary version
node_info_command_template = "cd /root/ceremonyclient/node/ && /root/ceremonyclient/node/{binary} -node-info"
latest_node_info_command, latest_binary = get_latest_binary_command(node_info_command_template)

if latest_node_info_command:
    commands.append({"command": latest_node_info_command, "key": "node_info", "parser": parse_node_info, "data_type": {"node_info_owned_balance": float, "node_info_unconfirmed_balance": float}, "update_dict": True})

# Execute initial commands to get initial config
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

# If node_info_peer_id is available, add the peer test command
if "node_info_peer_id" in initial_config and latest_binary:
    peer_id = initial_config["node_info_peer_id"]
    peer_test_command = f'cd /root/ceremonyclient/node/ && peer_id=$(/root/ceremonyclient/node/{latest_binary} -peer-id | grep -oP "(?<=Peer ID: ).*") && response=$(curl -s "https://dashboard-api.quilibrium.com/peer-test?peerId=$peer_id") && echo "$response"'
    peer_test_key = "peer_test"
    commands.append({"command": peer_test_command, "key": peer_test_key, "parser": lambda x, y: x and json.loads(x) or {} ,"update_dict": False})

# Execute all commands with the peer test command included
get_config(commands)
