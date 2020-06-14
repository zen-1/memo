# なんちゃってEPC自作入門
Python の勉強ついでに、EPCを自作してみよう！というわけで、MME、HSS、SGW、PGWを作っていきます。

![enter image description here](https://user-images.githubusercontent.com/1900544/84593371-e17ae600-ae86-11ea-872d-4aaf0fe4bfa1.png)


# 環境構築
EPCで使用するSCTPプロトコルは、Windowsがサポートしていないので、Windows 上の仮想環境で実行します。

## 環境

- Windows 10 64bit

## Vagrant インストール
Vagrant は仮想環境を簡単に構築してくれるツールです。下記からダウンロードしてインストールします。
- [Vagrant](https://www.vagrantup.com/)
Vagrant は裏で VirtualBox を使用するので、下記からダウンロードしてインストールします。
- [VirtualBox](https://www.virtualbox.org/)
コマンドプロンプトを起動し、任意のフォルダで下記のコマンドを実行し、初期設定を行います。
```
$ vagrant init ubuntu/focal64
```
Vagrantfile が生成されるので、下記の行のコメント(#)を削除します。
```
config.vm.network "private_network", ip: "192.168.33.10"
```
下記コマンドで仮想環境が起動/停止ができます。(初回は起動に時間が掛かります)
```
$ vagrant up     // 起動
$ vagrant halt   // 停止
```
vuname 
```
$ vagrant ssh
[vagrant@centos8 ~]$ sudo dnf update
```

## VS Code インストール

- [VS Code](https://azure.microsoft.com/ja-jp/products/visual-studio-code/)

## VS Code Remote SSH 

# SCTP
<!--stackedit_data:
eyJoaXN0b3J5IjpbMTE4NjgyMDcxNCwtOTQ0NjU2OTQzLDU5OT
Y4Njc2LC0xODU3ODg0OTAsLTE1MTA2NDg5NzIsLTkzNzMxOTU5
OCwxNDUxODM2MDQ4LDQ5NDU3MTIyMSwtMTA4NzYwNjg1NywtMT
A3NDgwMTk5OCwtOTEzOTgzMjYxLC01MDIzMzA0NzcsLTgzMzkx
MzQ3LC0xMjE0NjE3MDk5LC01MjE3Mjc2ODUsODkzODM3NTcxLD
E0Njk3MzYzMDcsMTE3NjU1NDk1LDE2OTQyNzQxMTBdfQ==
-->