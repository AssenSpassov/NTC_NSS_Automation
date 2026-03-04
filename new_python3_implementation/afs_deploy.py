#!/usr/bin/env python3
# Converted afs deploy script for Python3; preserves original behavior and CLI
import json
import time
import requests
import argparse
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class ApiConnector:
    def __init__(self, server_ip_address, username, password):
        self.server_ip_address = server_ip_address
        self.username = username
        self.password = password
        BASE_URL = 'https://%s:9440/PrismGateway/services/rest/%s'
        URL_API_V1 = 'v1/'
        URL_API_V2 = 'v2.0/'
        self.base_url_api_v1 = BASE_URL % (self.server_ip_address, URL_API_V1)
        self.base_url_api_v2 = BASE_URL % (self.server_ip_address, URL_API_V2)
        self.session = self.get_server_session(self.username, self.password)

    def get_server_session(self, username, password):
        s = requests.Session()
        s.auth = (username, password)
        s.verify = False
        s.headers.update({'Content-Type': 'application/json; charset=utf-8'})
        return s

    def _call_rest_api_get(self, api_url, apicall):
        cluster_url = api_url + apicall
        r = self.session.get(cluster_url)
        return r.status_code, r.json()

    def _call_rest_api_post(self, api_url, apicall, json_data):
        cluster_url = api_url + apicall
        r = self.session.post(cluster_url, data=json_data)
        return r.status_code, r.json()

    def call_rest_api_v1_get(self, apicall):
        return self._call_rest_api_get(self.base_url_api_v1, apicall)

    def call_rest_api_v1_post(self, apicall, json_data):
        return self._call_rest_api_post(self.base_url_api_v1, apicall, json_data)

    def call_rest_api_v2_get(self, apicall):
        return self._call_rest_api_get(self.base_url_api_v2, apicall)

    def call_rest_api_v2_post(self, apicall, json_data):
        return self._call_rest_api_post(self.base_url_api_v2, apicall, json_data)


class ConfigConnector:
    def __init__(self, cfg_file):
        with open(cfg_file, 'r') as fh:
            cfg_json = fh.read()
        self.configuration = json.loads(cfg_json)

    def get_config_param(self, config_item, config_param):
        return self.configuration[config_item][config_param]

    def set_config_param(self, config_item, config_param, param_value):
        self.configuration[config_item][config_param] = param_value

    def set_internal_network_uuid(self, config_item, uuid):
        self.configuration[config_item]['files_configuration']['internalNetwork']['uuid'] = uuid

    def set_external_network_uuid(self, config_item, uuid):
        self.configuration[config_item]['files_configuration']['externalNetworks'][0]['uuid'] = uuid


class NetConfigurator:
    def __init__(self, api_con):
        self.api_con = api_con
        self.networks = self.get_networks()

    def get_networks(self):
        status, networks = self.api_con.call_rest_api_v2_get('networks')
        return networks.get('entities', [])

    def _get_network_by_attribute(self, net_attr, attr_value):
        self.networks = self.get_networks()
        match = []
        for network in self.networks:
            if network.get(net_attr) == attr_value:
                match.append(network)
        return match

    def get_network_by_vlan(self, vlan_id):
        return self._get_network_by_attribute('vlan_id', vlan_id)

    def get_network_by_uuid(self, uuid):
        return self._get_network_by_attribute('uuid', uuid)

    def exist_network_with_vlan(self, vlan):
        for network in self.networks:
            if network.get('vlan_id') == vlan:
                return True
        return False

    def is_managed_network(self, network_uuid):
        nets = self.get_network_by_uuid(network_uuid)
        if not nets:
            return False
        network = nets[0]
        return bool(network.get('ip_config', {}).get('prefix_length'))

    def create_network(self, name, vlan):
        payload = json.dumps({'name': name, 'vlan_id': vlan})
        print('INFO: create_network: Creating network with info: ' + payload)
        status, resp = self.api_con.call_rest_api_v2_post('networks', payload)
        print('INFO: create_network: status code ' + str(status) + '. New network UUID: ' + resp.get('network_uuid', ''))
        return resp.get('network_uuid')


class FilesConfigurator:
    def __init__(self, api_con):
        self.api_con = api_con

    def software_download(self, files_version):
        payload = json.dumps({'name': files_version, 'version': files_version})
        print('INFO: software_download: Downloading files with info: ' + payload)
        status, resp = self.api_con.call_rest_api_v2_post(f'upgrade/afs/softwares/{files_version}/download', payload)
        return resp

    def get_software_information(self, files_version):
        status, resp = self.api_con.call_rest_api_v1_get('upgrade/afs/softwares')
        for s in resp.get('entities', []):
            if s.get('name') == files_version:
                return s
        return {}

    def get_software_download_percent(self, files_version):
        info = self.get_software_information(files_version)
        if not info:
            return 0
        cur = info.get('currentSizeInBytes', 0)
        tot = info.get('totalSizeInBytes', 1)
        return (cur * 100) / tot

    def deploy_files_server(self, files_config_json):
        print('INFO: deploy_files_server: Deploying files server with info: ' + json.dumps(files_config_json))
        status, resp = self.api_con.call_rest_api_v1_post('vfilers', json.dumps(files_config_json))
        return resp


class ClusterConfigurator:
    def __init__(self, api_con):
        self.api_con = api_con

    def new_public_key(self, name, key):
        payload = json.dumps({'name': name, 'key': key})
        print('INFO: new_public_key: Creating new public key with info: ' + payload)
        status, resp = self.api_con.call_rest_api_v2_post('cluster/public_keys', payload)
        return resp


class DeploymentOrchestrator:
    def __init__(self, cfg_file):
        self.cfg_con = ConfigConnector(cfg_file)
        self.api_con = ApiConnector(self.cfg_con.get_config_param(0, 'cluster_external_ipaddress'), self.cfg_con.get_config_param(0, 'username'), self.cfg_con.get_config_param(0, 'password'))
        self.net_conf = NetConfigurator(self.api_con)
        self.cluster_config = ClusterConfigurator(self.api_con)
        self.files_config = FilesConfigurator(self.api_con)

    def deploy_network(self):
        vlan = int(self.cfg_con.get_config_param(0, 'network_vlan'))
        exist = self.net_conf.exist_network_with_vlan(vlan)
        is_managed = True
        if exist:
            files_network = self.net_conf.get_network_by_vlan(vlan)
            print('INFO: deploy_network: Network exist with vlan: ' + files_network[0]['uuid'])
            is_managed = self.net_conf.is_managed_network(files_network[0]['uuid'])
        if is_managed:
            print('INFO: deploy_network: Creating new network')
            files_network_uuid = self.net_conf.create_network(self.cfg_con.get_config_param(0, 'network_name'), self.cfg_con.get_config_param(0, 'network_vlan'))
            files_network = self.net_conf.get_network_by_uuid(files_network_uuid)
        else:
            print('INFO: deploy_network: Unmanaged network with vlan {0} already exist.'.format(vlan))
            print('INFO: deploy_network: Using network "{0}" with uuid: "{1}" instead'.format(files_network[0]['name'], files_network[0]['uuid']))
            self.cfg_con.set_config_param(0, 'network_name', files_network[0]['name'])
        return True

    def deploy_ssh_key(self):
        self.cluster_config.new_public_key(self.cfg_con.configuration[0]['pub_key_name'], self.cfg_con.configuration[0]['pub_key_string'])
        return True

    def deploy_files(self):
        files_network = self.net_conf.get_network_by_vlan(int(self.cfg_con.get_config_param(0, 'network_vlan')))
        self.cfg_con.set_internal_network_uuid(0, files_network[0]['uuid'])
        self.cfg_con.set_external_network_uuid(0, files_network[0]['uuid'])
        self.files_config.software_download(self.cfg_con.configuration[0]['files_software_version'])
        info = self.files_config.get_software_information(self.cfg_con.configuration[0]['files_software_version'])
        percent = self.files_config.get_software_download_percent(self.cfg_con.configuration[0]['files_software_version'])
        while percent < 100:
            percent = self.files_config.get_software_download_percent(self.cfg_con.configuration[0]['files_software_version'])
            print(f"INFO: deploy_files: Files version: {info.get('name','')} status {info.get('status','')} download {percent}%")
            time.sleep(10)
        print('INFO: deploy_files: 30 sec waiting for software catalog to refresh.')
        time.sleep(30)
        self.files_config.deploy_files_server(self.cfg_con.configuration[0]['files_configuration'])
        return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('config_file', type=str)
    parser.add_argument('-k', '--add-pub-key', action='store_true')
    parser.add_argument('-n', '--create-network', action='store_true')
    parser.add_argument('-f', '--deploy-files', action='store_true')
    args = parser.parse_args()
    deploy = DeploymentOrchestrator(args.config_file)
    if args.add_pub_key:
        deploy.deploy_ssh_key()
    if args.create_network:
        deploy.deploy_network()
    if args.deploy_files:
        deploy.deploy_files()
