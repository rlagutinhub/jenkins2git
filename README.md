# jenkins2git

* Periodic backup of Jenkins configs to Git

### Create user ssh keys from command line on Jenkins host:

```
su -s /bin/bash jenkins
cd /var/lib/jenkins

ssh-keygen -b 2048 -t rsa -C "jenkins@$(hostname -f)"
cat ~/.ssh/id_rsa.pub
```

### Create user and add ssh key in Gitlab:

* Create user "jenkins"
* Users => Jenkins => Impersonate => Personal Settings => SSH keys: paste contents of id_rsa.pub here

### Create repository in Gitlab:

* Create repository "jenkins-configs"
* Copy repo link to clipboard
* Goto Repository => Settings => Members
* Add Jenkins as Maintainer (only maintainer can do an initial push to empty Gitlab repo)

### Create repository from command line on Jenkins host:

```
su -s /bin/bash jenkins
cd /var/lib/jenkins

git init
git config --global user.name Jenkins
git config --global user.email "jenkins@$(hostname -f)"
git config --global -l

git remote add origin PASTE_HERE_REPO_LINK_FROM_GITLAB
git remote show origin # approve host key verification

cat <<EOF > .gitignore
.*
!/.gitignore
EOF

git add .gitignore
git commit -m 'Jenkins init commit'
git status

git push origin master
```

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

### Protect repository in Gitlab::

* Settings => Members: decrease Jenkins permissions from Maintainer to Developer
* Settings => Repository => Protected branches: master => Allow to push: change from Maintainers to Maintainers+Developers

### Restore to current (last) commit from command line on Jenkins host:

```
systemctl stop jenkins
su -s /bin/bash jenkins

cp -rp /var/lib/jenkins /var/lib/jenkins.$(date +%F)
cd /var/lib/jenkins

rm -rf *
rm -rf .git*

git init
git config --global user.name Jenkins
git config --global user.email "jenkins@$(hostname -f)"
git config --global -l

git remote add origin PASTE_HERE_REPO_LINK_FROM_GITLAB
git remote show origin # approve host key verification

git fetch origin
git branch

git checkout -b master --track origin/master
git reset origin/master
git status

git push origin master

cd plugins && sh _jenkins.plugins.get.sh # restore plugins!

exit
systemctl start jenkins
tail -f /var/log/jenkins/jenkins.log
```

### Restore to old commit from command line on Jenkins host:

```
systemctl stop jenkins
su -s /bin/bash jenkins

cp -rp /var/lib/jenkins /var/lib/jenkins.$(date +%F)
cd /var/lib/jenkins

rm -rf *
rm -rf .git*

git init
git config --global user.name Jenkins
git config --global user.email "jenkins@$(hostname -f)"
git config --global -l

git remote add origin PASTE_HERE_REPO_LINK_FROM_GITLAB
git remote show origin # approve host key verification

git fetch origin
git branch

git checkout -b master --track origin/master
git reset origin/master
git status

git log --pretty=format:"%h %ad | %s%d [%an]" --graph --date=short
git revert PASTE_HERE_OLD_COMMIT_ID..PASTE_HERE_NEW_COMMIT_ID # revert by range and not reset!
git status

git push origin master

cd plugins && sh _jenkins.plugins.get.sh # restore plugins!

exit
systemctl start jenkins
tail -f /var/log/jenkins/jenkins.log
```

### See also:

* https://github.com/sue445/jenkins-backup-script
* https://github.com/ilyaevseev/jenkins2git
* https://gist.github.com/cenkalti/5089392
