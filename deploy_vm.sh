#!/bin/bash
# 
# Wrapper for deploying our demo VMs on KVM

# Pull in our local envioronment

if [ -f local.env ]; then
    source local.env
else
   echo "You need to supply a local.env file - refernce local.env.sample">&2
   exit -1
fi

# For Centos 7
C7_BASE_IMAGE=CentOS-7-x86_64-GenericCloud-2009.qcow2

# For Centos 8
C8_BASE_IMAGE=CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2

# For RHEL 7.9
R7_BASE_IMAGE=rhel-server-7.9-x86_64-kvm.qcow2

# For RHEL 8.5
R8_BASE_IMAGE=rhel-8.5-x86_64-kvm.qcow2

# Define our virtual environment
# Make sure the VM_BRIDE matches a bridge or nat network in your
# libvirt environment

VM_NAME=LEAPP2RHEL
VM_MEMORY=2048
VM_CPU=2
VM_BRIDGE=${VM_BRIDGE:-virbr1}

VM_IMAGE=${VM_DIR}/${VM_NAME}.qcow2

# We create a working qcow2 snapshot based off the cloud ready image
# This has a default root password, removes cloud-init  and
# injects a user ssh pubkey
#
vm_create_working_snapshot()
{
    VM_BASE=${BASE_DIR}/${BASE_IMAGE}

    # Create our working snapshot
    qemu-img create -f qcow2 -F qcow2 \
    -o backing_file=${VM_BASE} ${VM_IMAGE}

    # If we're going to add an SSH Key we need to re-label due to SELinux
    ADD_SSH_KEY=

    [ -f /home/${MY_USER}/.ssh/id_rsa.pub ] && \
      ADD_SSH_KEY="--ssh-inject root:file:/home/${MY_USER}/.ssh/id_rsa.pub --selinux-relabel"

    # Enable root password login and remove cloud-init
    # Add our user ssh pubkey if available

    virt-customize -a ${VM_IMAGE} \
     --root-password password:password --uninstall cloud-init \
     ${ADD_SSH_KEY} \
     --run-command 'echo PermitRootLogin yes >> /etc/ssh/sshd_config'
}

# Create our KVM virtual machine
vm_create ()
{

    virt-install --name ${VM_NAME} --memory ${VM_MEMORY} --vcpus ${VM_CPU} \
        --disk path=$VM_IMAGE,format=qcow2,bus=scsi,discard=unmap \
        --os-variant=${OS_VARIANT} \
        --controller=type=scsi,model=virtio-scsi \
        --connect qemu:///system \
        --virt-type kvm \
        --noautoconsole \
        --import \
        --network type=bridge,source=${VM_BRIDGE} --graphics vnc
}


# Connect to our VM console
vm_console ()
{
    virsh console ${VM_NAME}
}

vm_destroy ()
{
    virsh destroy ${VM_NAME}
    virsh undefine ${VM_NAME}
    rm ${VM_IMAGE} 
}

usage ()
{
    echo "Usage: $N {create (centos7|centos8|rhel7|rhel8) |status|remove|cleanup|destory|console}" >&2
    exit 1
}
case "$1" in
  create)
        case "$2" in
          centos7)
            OS_VARIANT=centos7
            BASE_IMAGE=${C7_BASE_IMAGE}
            ;;
          centos8)
            OS_VARIANT=centos8
            BASE_IMAGE=${C8_BASE_IMAGE}
            ;;
          rhel7)
            OS_VARIANT=rhel7.9
            BASE_IMAGE=${R7_BASE_IMAGE}
            ;;
          rhel8)
            OS_VARIANT=rhel8.5
            BASE_IMAGE=${R8_BASE_IMAGE}
            ;;
          *)
            usage
            ;;
        esac

        vm_create_working_snapshot 
        vm_create
        vm_console
        ;;
        
  console)
        vm_console
        ;;

  status)
        virsh dominfo ${VM_NAME}
        ;;
  delete|cleanup|remove|destroy)
        vm_destroy
        ;;
  *)
        usage
        ;;
esac

