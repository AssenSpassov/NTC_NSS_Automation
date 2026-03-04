#!/usr/bin/env python3
"""
Python3 replacement for 000-orchestrator.sh minimal feature set:
- package payload files into a tar.gz
- replace passwords inside payload/afs_cluster_configs/*.json when requested
- copy archive to clusters using scp
- extract and execute payload/*.sh scripts remotely via ssh
Preserves colored output using zzz_functions.py
"""
import argparse
import os
import tarfile
import subprocess
import json
import time
from pathlib import Path
from zzz_functions import print_blue, print_green, print_red, print_yellow

BASEDIR = Path(__file__).resolve().parent
LOCAL_PAYLOAD = BASEDIR / 'payload'
CVM_PKG_BASENAME = 'cvm.pkg.tar.gz'
CVM_PATH = '/home/nutanix/tmp/ntc/'
SSH_OPTS = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR'
SCP_OPTS = SSH_OPTS
SSH_KEY_FILE = 'id_rsa.pub'


def create_archive(out_name):
    with tarfile.open(out_name, 'w:gz') as tar:
        for entry in LOCAL_PAYLOAD.glob('*'):
            if entry.name.startswith('.'):
                continue
            tar.add(entry, arcname=entry.name)
    return out_name


def replace_passwords_for_clusters(clusters, passwords):
    for cluster, pw in zip(clusters, passwords):
        cfg_path = LOCAL_PAYLOAD / 'afs_cluster_configs' / f'{cluster}.json'
        if not cfg_path.exists():
            print_red(f"Config for {cluster} not found: {cfg_path}")
            continue
        data = json.loads(cfg_path.read_text())
        if isinstance(data, dict) and 'password' in data:
            data['password'] = pw
            cfg_path.write_text(json.dumps(data, indent=2))
        elif isinstance(data, list) and len(data) > 0 and 'password' in data[0]:
            data[0]['password'] = pw
            cfg_path.write_text(json.dumps(data, indent=2))
        print_green(f"Replaced password for {cluster} in {cfg_path}")


def scp_copy(archive, cluster):
    dest = f"{cluster}:{CVM_PATH}"
    cmd = f"scp {SCP_OPTS} {archive} {dest}"
    print_blue(f"Copying {archive} to {cluster}...")
    ret = subprocess.run(cmd, shell=True)
    return ret.returncode == 0


def ssh_run(cluster, cmd):
    full = f"ssh {SSH_OPTS} {cluster} \". /etc/profile ; cd {CVM_PATH} ; {cmd} \""
    print_blue(f"Executing on {cluster}: {cmd}")
    ret = subprocess.run(full, shell=True)
    return ret.returncode == 0


def deploy(clusters_list, passwords_list):
    clusters = [c.strip().lower() for c in clusters_list]
    create_archive_name = f"{int(time.time())}-{CVM_PKG_BASENAME}"
    print_yellow("Creating local archive for all clusters...")
    archive_path = BASEDIR / create_archive_name
    create_archive(archive_path)
    print_green(f"Archive {archive_path} created")

    for idx, cluster in enumerate(clusters):
        if passwords_list:
            replace_passwords_for_clusters([cluster], [passwords_list[idx]])
        ok = scp_copy(archive_path, cluster)
        if not ok:
            print_red(f"[Copy failed] for {cluster}")
            continue
        ssh_run(cluster, f"tar -C {CVM_PATH} -zxvf {CVM_PATH}{archive_path.name}")
        for script in (LOCAL_PAYLOAD).glob('*.sh'):
            remote_cmd = f"{CVM_PATH}{script.name}"
            ssh_run(cluster, f"chmod +x {remote_cmd} && {remote_cmd}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-L', type=int, help='Lapras mode (1 suppress colors)')
    parser.add_argument('-T', action='store_true', help='Testing mode')
    parser.add_argument('-c', type=str, help='Clusters (space separated)')
    parser.add_argument('-p', type=str, help='Passwords (space separated)')
    args = parser.parse_args()
    clusters = args.c.split() if args.c else []
    passwords = args.p.split() if args.p else []
    deploy(clusters, passwords)
