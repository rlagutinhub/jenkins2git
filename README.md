# jenkins2git

* Periodic backup of Jenkins configs to Git

### Create user and repository in Gitlab:

* Create user "jenkins"
* Create repository "jenkins-configs"
* Copy repo link to clipboard
* Goto Repository => Settings => Members
* Add Jenkins as Maintainer (only maintainer can do an initial push to empty Gitlab repo)

### Create repository from command line on Jenkins host:

```
sudo -Hiu jenkins
cd ~
git init
git config --global user.name Jenkins
git config --global user.email "jenkins@$(hostname -f)"
git remote add origin PASTE_HERE_REPO_LINK_FROM_GITLAB
ssh-keygen
cat ~/.ssh/id_rsa.pub
```

### Gitlab:

* Users => Jenkins => Impersonate => Personal Settings => SSH keys: paste contents of id_rsa.pub here

### Create job in Jenkins GUI:

* Name = Backup Jenkins configs to Git
* Type = Free job
* Label = master (you should edit Master node and create this label!)
* SCM = None
* Build = Build Periodically
* Schedule = `20 04 * * *`
* Build step = Execute Shell
* Paste the contents of [jenkins2git.sh](jenkins2git.sh)
* Save

### Gitlab:

* Settings => Members: decrease Jenkins permissions from Maintainer to Developer
* Settings => Repository => Protected branches: master => Allow to push: change from Maintainers to Maintainers+Developers

### Quick setup:

```
1. su -s /bin/bash jenkins
2. cd /var/lib/jenkins && git init
3. git config --global user.name Jenkins
4. git config --global user.email "jenkins@$(hostname -f)"
5. git config --global -l
6. git remote add origin git@git.dev.mta4.ru:mta4ru/jenkins-configs.git
7. git remote show origin
8. Exec jenkins job


1. systemctl stop jenkins
2. su -s /bin/bash jenkins
3. cd /var/lib/jenkins && rm -rf *
4. rm -rf .git .gitconfig
5. git init
6. git config --global user.name Jenkins
7. git config --global user.email "jenkins@$(hostname -f)"
8. git config --global -l
9. git remote add origin git@git.dev.mta4.ru:mta4ru/jenkins-configs.git
10. git remote show origin
11. git pull origin master
12. cd plugins && sh jenkins.plugins.restore.sh
13. # find . -name "*.hpi" -exec bash -c 'mv "$1" "${1%.hpi}".jpi' - '{}' \;
14. exit
15. systemctl start jenkins
16. tail -f /var/log/jenkins/jenkins.log
```

### See also:

* https://github.com/sue445/jenkins-backup-script
* https://github.com/ilyaevseev/jenkins2git
* https://gist.github.com/cenkalti/5089392
