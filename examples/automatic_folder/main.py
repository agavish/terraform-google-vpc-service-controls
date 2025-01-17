# -*- coding: utf-8 -*-

import os
import subprocess
import urllib.request
import os
from shutil import copytree, copyfile, ignore_patterns, rmtree

# Version of Terraform that we're using
TERRAFORM_VERSION = '0.12.8'

# Download URL for Terraform
PLATFORM = 'linux'
TERRAFORM_DOWNLOAD_URL = (
    'https://releases.hashicorp.com/terraform/%s/terraform_%s_%s_amd64.zip'
    % (TERRAFORM_VERSION, TERRAFORM_VERSION, PLATFORM))

# Paths where Terraform should be installed
TERRAFORM_DIR = os.path.join('/tmp', 'terraform_%s' % TERRAFORM_VERSION)
TERRAFORM_PATH = os.path.join(TERRAFORM_DIR, 'terraform')

PROJECT_DIR = os.path.join('/tmp', 'project')

def check_call(args, cwd=None, printOut=False):
    """Wrapper for subprocess that checks if a process runs correctly,
    and if not, prints stdout and stderr.
    """
    proc = subprocess.Popen(args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=cwd)
    stdout, stderr = proc.communicate()
    if proc.returncode != 0:
        print(stdout.decode())
        print(stderr.decode())
        raise subprocess.CalledProcessError(
            returncode=proc.returncode,
            cmd=args)
    if printOut:
        print(stdout.decode())
        print(stderr.decode())


def install_terraform():
    """Install Terraform."""
    if os.path.exists(TERRAFORM_PATH):
        return

    print(TERRAFORM_PATH)

    urllib.request.urlretrieve(TERRAFORM_DOWNLOAD_URL, '/tmp/terraform.zip')

    check_call(['unzip', '-o', '/tmp/terraform.zip', '-d', TERRAFORM_DIR], '/tmp')

    check_call([TERRAFORM_PATH, '--version'])


def handler(event, context):
    print(event)

    if os.path.exists(PROJECT_DIR):
        rmtree(PROJECT_DIR)

    copytree('.', PROJECT_DIR, ignore=ignore_patterns('.terraform', 'credentials.json'))

    install_terraform()

    check_call([TERRAFORM_PATH, 'init'],
                  cwd=PROJECT_DIR,
                  printOut=True)
    check_call([TERRAFORM_PATH, 'apply',
        '-target=module.service_perimeter', '-no-color',
        '-auto-approve', '-lock=false',
        '-lock-timeout=300s'],
                  cwd=PROJECT_DIR,
                  printOut=True)
    check_call([TERRAFORM_PATH, 'output', '-json'],
                  cwd=PROJECT_DIR,
                  printOut=True)
