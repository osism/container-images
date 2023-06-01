import os
import requests
import subprocess
import sys
import time
import yaml

from munch import Munch
from loguru import logger


def prechecks() -> None:
    # wait until gpg is present
    counter = 0
    while not os.path.exists('/opt/aptly/public/gpgkey'):
        if counter == 0:
            logger.info('WAITING FOR GPG KEY')
        counter = counter + 1
        if counter == 12:
            counter = 0
        time.sleep(5)

    # check and wait for possible other running processes
    counter = 0
    while os.path.exists('/opt/aptly/aptly_wrapper.lock'):
        if counter == 0:
            logger.info('WAITING FOR OTHER JOB TO FINISH')
        counter = counter + 1
        if counter == 12:
            counter = 0
        time.sleep(5)

    # create lock file to prevent parallel processes
    with open('/opt/aptly/aptly_wrapper.lock', 'w') as file:
        file.write(time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime()))
        file.write('\n')
        file.write(os.getenv("HOSTNAME", ""))
        file.write('\n')


def get_global_config() -> Munch:
    config = Munch()
    for file in os.listdir('/opt/aptly_wrapper_config'):
        if file.startswith('.'):
            continue
        with open(f"/opt/aptly_wrapper_config/{file}", 'r') as config_file:
            config[file] = config_file.read().rstrip()

    # check if we are running for the first time
    config.update = os.path.exists('/opt/aptly/db')
    if config.update:
        config.mode = 'UPDATE'
    else:
        config.mode = 'INITIAL SETUP'

    return config


def runner(command: str) -> None:
    logger.info(command)
    # unfortunately we have to pipe directly to stdout as subprocess.PIPE would
    # overflow within seconds due to the large amount of log messages generated
    process = subprocess.Popen(
        command,
        stdout=sys.stdout,
        stderr=sys.stderr,
        text=True,
        shell=True
    )
    counter = 0
    while True:
        counter = counter + 1
        if process.poll() is not None:
            logger.info('PROCESS FINISHED')
            break
        else:
            time.sleep(5)
            if counter == 12:
                counter = 0
                logger.info('still working ...')


def get_mirror_configs(sources_url: str) -> list:
    result = requests.get(sources_url)
    try:
        mirror_configs = yaml.safe_load(result.content)['deb_mirrors']
    except yaml.YAMLError as exc:
        logger.critical(exc)
    return mirror_configs


def import_gpg_keys(mirror_configs: list) -> None:
    for mirror_config in mirror_configs:
        for gpg_url in mirror_config['gpg_urls']:
            command = f"curl -sL '{gpg_url}' | gpg1 --no-default-keyring --keyring trustedkeys.gpg --import"
            # for some unknown reason, gpg1 does not use stdout, so success messages will also be send to stderr :(
            runner(command)


def create_aptly_mirrors(mirror_configs: list, config: Munch) -> list:
    mirror_names = []
    for index, mirror_config in enumerate(mirror_configs):
        mirror_name = f"mirror_{index:06d}"
        mirror_names.append(mirror_name)

        if not config.update:
            command = f"aptly mirror create {mirror_name} {mirror_config['mirror']}"
            runner(command)

    return mirror_names


def update_aptly_mirrors(mirror_names: list) -> None:
    for mirror_name in mirror_names:
        command = f"aptly mirror update {mirror_name}"
        runner(command)


def create_aptly_snapshots(mirror_names: list, config: Munch) -> list:
    snapshot_names = []
    for index, mirror_name in enumerate(mirror_names):
        if config.update:
            snapshot_name = f"snapshot_new_{index:06d}"
        # initial setup
        else:
            snapshot_name = f"snapshot_{index:06d}"
        snapshot_names.append(snapshot_name)

        command = f"aptly snapshot create {snapshot_name} from mirror {mirror_name}"
        runner(command)

    return snapshot_names


def merge(snapshot_names: list, config: Munch) -> None:
    if config.update:
        command = f"aptly snapshot merge {config.merged_mirror_name}-new"
    else:
        command = f"aptly snapshot merge {config.merged_mirror_name}"

    for snapshot_name in snapshot_names:
        command = f"{command} {snapshot_name}"
    runner(command)


def publish(config: Munch) -> None:
    if config.update:
        command = f"aptly publish switch -passphrase='{config.password}' {config.release} {config.merged_mirror_name} {config.merged_mirror_name}-new"
    else:
        command = f"aptly publish snapshot -distribution={config.release} -passphrase='{config.password}' {config.merged_mirror_name} {config.merged_mirror_name}"
    runner(command)


def cleanup(snapshot_names: list, config: Munch) -> None:
    if config.update:
        command = f"aptly snapshot drop {config.merged_mirror_name}"
        runner(command)

        for snapshot_new_name in snapshot_names:
            snapshot_name = snapshot_new_name.replace("_new_", "_")
            command = f"aptly snapshot drop {snapshot_name}"
            runner(command)
            command = f"aptly snapshot rename {snapshot_new_name} {snapshot_name}"
            runner(command)

        command = f"aptly snapshot rename {config.merged_mirror_name}-new {config.merged_mirror_name}"
        runner(command)

    os.remove('/opt/aptly/aptly_wrapper.lock')


def main() -> None:
    prechecks()
    config = get_global_config()
    logger.info(f"STARTED {config.mode}")
    mirror_configs = get_mirror_configs(sources_url=config.sources_url)
    import_gpg_keys(mirror_configs=mirror_configs)
    mirror_names = create_aptly_mirrors(mirror_configs=mirror_configs, config=config)
    update_aptly_mirrors(mirror_names=mirror_names)
    snapshot_names = create_aptly_snapshots(mirror_names=mirror_names, config=config)
    merge(snapshot_names=snapshot_names, config=config)
    publish(config=config)
    cleanup(snapshot_names=snapshot_names, config=config)
    logger.info(f"FINISHED {config.mode}")


if __name__ == '__main__':
    main()
