.. _yum_repo:

===================================
 Percona :program:`yum` Repository
===================================

The |Percona| :program:`yum` repository supports popular *RPM*-based operating systems, including the *Amazon Linux AMI*.

The easiest way to install the *Percona Yum* repository is to install an *RPM* that configures :program:`yum` and installs the `Percona GPG key <http://www.percona.com/downloads/RPM-GPG-KEY-percona>`_. You can also do the installation manually.

Automatic Installation
======================

Execute the following command as a ``root`` user, replacing ``x86_64`` with ``i386`` if you are not running a 64-bit operating system: ::

  $ yum install http://www.percona.com/downloads/percona-release/percona-release-0.0-1.x86_64.rpm

You should see some output such as the following: ::

  Retrieving http://www.percona.com/downloads/percona-release/percona-release-0.0-1.x86_64.rpm
  Preparing...                ########################################### [100%]
     1:percona-release        ########################################### [100%]

The RPMs for the automatic installation are available at http://www.percona.com/downloads/percona-release/ and include source code.

Manual Installation
===================

To install the repository manually, place the following into a new file named :file:`/etc/yum.repos.d/Percona.repo`: ::

  [percona]
  name = CentOS $releasever - Percona
  baseurl=http://repo.percona.com/centos/$releasever/os/$basearch/
  enabled = 1
  gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-percona
  gpgcheck = 1

Also, copy the `Percona GPG key <http://www.percona.com/downloads/RPM-GPG-KEY-percona>`_  into a file named :file:`/etc/pki/rpm-gpg/RPM-GPG-KEY-percona`.

Testing The Repository
======================

Make sure packages are downloaded from the repository, by executing the following command as root: ::

  yum list | grep percona

You should see output similar to the following: ::

  percona-release.x86_64                     0.0-1                         @/percona-release-0.0-1.x86_64
  ...
  Percona-Server-client-55.x86_64            5.5.35-rel33.0.611.rhel6      percona
  Percona-Server-devel-55.x86_64             5.5.35-rel33.0.611.rhel6      percona
  Percona-Server-server-55.x86_64            5.5.35-rel33.0.611.rhel6      percona
  Percona-Server-shared-55.x86_64            5.5.35-rel33.0.611.rhel6      percona
  Percona-Server-test-55.x86_64              5.5.35-rel33.0.611.rhel6      percona
  ...
  percona-xtrabackup.x86_64                  2.1.7-721.rhel6               percona


Supported Platforms
===================

  *  ``x86_64``
  *  ``i386``

Supported Releases
==================

The *CentOS* repositories should work well with *Red Hat Enterprise Linux* too, provided that :program:`yum` is installed on the server.

* *CentOS* 5 and *RHEL* 5

* *CentOS* 6 and *RHEL* 6

* *Amazon Linux AMI* (works the same as *CentOS* 5)

Percona `yum` Experimental repository
=====================================

Percona offers fresh beta builds from the experimental repository. To subscribe to the experimental repository, install the experimental *RPM*: ::

 yum install http://repo.percona.com/testing/centos/6/os/noarch/percona-testing-0.0-1.noarch.rpm

.. note:: 
 This repository works for both RHEL/CentOS 5 and RHEL/CentOS 6
