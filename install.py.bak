#!/usr/bin/env python3

import yaml
import json
import os
import shutil
import glob
import stat
import pprint
import subprocess
import string
import secrets
import datetime
import logging
import sys
import pprint

install_dir = "/root/.road-runner"
tmp_dir = install_dir + '/tmp'
begin_time = datetime.datetime.now()

logger = logging.getLogger()
logger.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s | %(levelname)s | %(message)s')

file_handler = logging.FileHandler('/var/log/road-runner.log')
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)

logger.addHandler(file_handler)

# concatenate temporary files in dirName to fileName then return fileName
def concatenateFiles(dirName, createFile):
    
    with open(createFile, "w") as outfile:
        for filename in os.listdir(dirName):
            with open(dirName + '/' + filename) as infile:
                contents = infile.read()
                outfile.write(contents)
                
    return createFile
    
def createDirectoryPath(dir):
    
    if not os.path.exists(dir):
        try:
            os.makedirs(dir)
        except OSError as error:
            print("Error: %s : %s" % (dir, error.strerror))
            return False
            
    return True
            
def cleanTmpDir(dirName):

    files = glob.glob(dirName + '/*.yaml')

    for file in files:
        try:
            os.remove(file)
        except OSError as error:
            print("Error: %s : %s" % (file, error.strerror))
            return False
            
    return True
            
def generatePassword(length):
 
    alphabet = string.ascii_letters + string.digits + '!@#$%^'
    password = ''.join(secrets.choice(alphabet) for i in range(length))
    
    return password
    
def printBanner(text):
    
    str_length = len(text)
    dashes = int((80 - (str_length + 2)) / 2)
    
    print('=' * 80)
    print ("%s %s %s" % (('=' * (dashes - 2)), text, ('=' * (80 - dashes - str_length))))
    print('=' * 80)
   
    return True

if __name__ == '__main__':

    # # delete the installation directory if it exists
    # isExist = os.path.exists(install_dir)
    # if isExist:
        # shutil.rmtree(install_dir)
    
    # create the installation directory
    createDirectoryPath(install_dir)
    
    # always cd into install_dir
    os.chdir(install_dir)
    
    # install git
    os.system("apt update")
    os.system("apt install -y git")
    
    # install road-runner distribution
    os.system("git clone https://github.com/rstober/road-runner-edge.git %s" % install_dir)
    
    # create the tmp directory
    createDirectoryPath(tmp_dir)
    
    # load the python3 module
    exec(open('/cm/local/apps/environment-modules/4.5.3/Modules/default/init/python.py').read())
    os.environ['MODULEPATH'] = '/cm/local/modulefiles:/cm/shared/modulefiles'
    module('load','python3')
    module('load','cmsh')
    
    stream = open('install_config.yaml', 'r')
    dictionary = yaml.safe_load(stream)
    
    # pp = pprint.PrettyPrinter(indent=4)
    # for key in dictionary:
        # pp.pprint(dictionary)
        
    #sys.exit("Exiting")
    
    # create the ansible facts.d directory
    createDirectoryPath('/etc/ansible/facts.d')
    
    # write the ansible custom.fact directory 
    with open('/etc/ansible/facts.d/custom.fact', 'w') as write_file:
        json.dump(dictionary, write_file, indent=2)
    
    # create an ansible roles directory for each role
    roles = list(("networks", "apt_upgrade_node", "software_images", "categories", "kubernetes", "nodes", "packages", "csps", "users", "wlms", "autoscaler", "jupyter", "apps"))
    for role in roles:
        createDirectoryPath('roles/' + role + '/tasks')
        createDirectoryPath('roles/' + role + '/vars')
        createDirectoryPath('roles/' + role + '/tmp')
    
    # install ansible base
    os.system('pip install ansible==' + dictionary["ansible_version"])
    
    # install the brightcomputing.bcm100 Ansible collection
    os.system("ansible-galaxy collection install brightcomputing.bcm100")
   
    # copy the CMSH aliases, bookmarks and scriptlets to their proper locations
    createDirectoryPath('/root/.cm/cmsh')
    shutil.copyfile('cmshrc', '/root/.cmshrc')
    shutil.copyfile('bookmarks-cmsh', '/root/.bookmarks-cmsh')
    shutil.copyfile('du.cmsh', '/root/.cm/cmsh/du.cmsh')
    shutil.copyfile('cu.cmsh', '/root/.cm/cmsh/cu.cmsh')
    shutil.copyfile('si.cmsh', '/root/.cm/cmsh/si.cmsh')
    shutil.copyfile('dp.cmsh', '/root/.cm/cmsh/dp.cmsh')
    shutil.copyfile('hosts', '/etc/ansible/hosts')
    shutil.copyfile('ansible.cfg', '/root/.ansible.cfg')
    
    printBanner('Preparing playbooks')  
    
    shutil.copyfile("bright-ansible-vars", install_dir + "/roles/license/vars/main.yaml")    
    os.system('ansible-playbook -ilocalhost, -v install-license.yml')
        
    if "software_images" in dictionary:

        shutil.copyfile("bright-ansible-vars", install_dir + "/roles/software_images/vars/main.yaml")
    
        for image in dictionary["software_images"]:
        
            print(image)

            initrd_file = '/cm/images/' + image["name"] + '/boot/initrd-' + image["kernel_release"]
            
            os.system('ansible-playbook -ilocalhost, -v --extra-vars "index={index} image_name={image_name} clone_from={clone_from} image_path={image_path} kernel_release={kernel_release} image_backup={image_backup}" create-software-image-pb.yaml'.format(index=index, image_name=image["name"], clone_from=image["clone_from"],image_path=image["path"], kernel_release=image["kernel_release"], image_backup=image["backup"]))
            
        concatenateFiles(dictionary["install_dir"] + '/roles/software_images/tmp', 'roles/software_images/tasks/main.yaml')
        #cleanTmpDir(dictionary["install_dir"] + '/roles/software_images/tmp')  
        
    if "categories" in dictionary:
    
        index=0
        
        shutil.copyfile("bright-ansible-vars", install_dir + "/roles/categories/vars/main.yaml")
    
        for category in dictionary["categories"]:
        
            index+=1
            
            os.system('ansible-playbook -ilocalhost, -v --extra-vars "index={index} category_name={name} clone_from={clone_from} software_image={software_image}" create-category-pb.yaml'.format(index=index, name=category["name"], clone_from=category["clone_from"], software_image=category["software_image"]))
            
        concatenateFiles(dictionary["install_dir"] + '/roles/categories/tmp', 'roles/categories/tasks/main.yaml')
        #cleanTmpDir(dictionary["install_dir"] + '/roles/categories/tmp') 
        
    if "users" in dictionary:
    
        index=0
        shutil.copyfile("bright-ansible-vars", install_dir + "/roles/users/vars/main.yaml")
        password=generatePassword(20)
        
        os.system('ansible-playbook -ilocalhost, -v --extra-vars "password={password}" add-user-password-pb.yaml'.format(password=password))
        
        for user in dictionary["users"]:
            
            index+=1
           
            os.system('ansible-playbook -ilocalhost, -v --extra-vars "index={index} username={username} password={password}" add-user-pb.yaml'.format(index=index, username=user, password=password))
        
        concatenateFiles(dictionary["install_dir"] + '/roles/users/tmp', 'roles/users/tasks/main.yaml')
        cleanTmpDir(dictionary["install_dir"] + '/roles/users/tmp')
    
    #sys.exit("Exit after users")        
    
    printBanner('Run the playbooks')
    
    #os.system('ansible-playbook -vv site.yaml')
    
    printBanner('Done')
    
    print("Script time: %s" % (datetime.datetime.now() - begin_time))
                