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

コマンドプロンプトを起動し、任意のフォルダで下記のコマンドを実行し、Ubuntu 20.04 の初期設定を行います。
```
$ vagrant init bento/ubuntu-20.04
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
```
$ vagrant ssh
vagrant
```

## VS Code インストール

- [VS Code](https://azure.microsoft.com/ja-jp/products/visual-studio-code/)

## VS Code Remote SSH 

# SCTP
<!--stackedit_data:
eyJoaXN0b3J5IjpbMTgxOTA3NTUxOSwtOTM3MzE5NTk4LDE0NT
E4MzYwNDgsNDk0NTcxMjIxLC0xMDg3NjA2ODU3LC0xMDc0ODAx
OTk4LC05MTM5ODMyNjEsLTUwMjMzMDQ3NywtODMzOTEzNDcsLT
EyMTQ2MTcwOTksLTUyMTcyNzY4NSw4OTM4Mzc1NzEsMTQ2OTcz
NjMwNywxMTc2NTU0OTUsMTY5NDI3NDExMF19
-->