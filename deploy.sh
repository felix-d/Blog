#! /bin/bash
modified_files=$(git diff-tree --no-commit-id --name-only -r HEAD | grep "^public/" | sed 's:^public/::')

pushd public
for f in $modified_files
do
    printf "\n\e[35mUploading \e[32m$f...\e[39m"
    printf "\e[34m"
    curl --ftp-create-dirs -T $f -u $FTP_USER:$FTP_PASS ftp://ftp.software-rambles.com/$f
    printf "\e[39m"
done
