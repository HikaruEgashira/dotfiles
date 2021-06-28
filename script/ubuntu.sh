#!/bin/bash

# ミラーリポジトリの設定
echo "★ Setting apt sources..."x
sudo sed -i.bak -e 's%http://[^ ]\+%mirror://mirrors.ubuntu.com/mirrors.txt%g' /etc/apt/sources.list

# update
sudo apt update && sudo apt upgrade -y

# zsh, build-essentialインストール

sudo apt install zsh build-essential

# デフォルトシェルをzshに

chsh -s $(which zsh)
