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
$ vagrant init ubuntu/bionic64
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
[vagrant@ubuntu-bionic ~]$ sudo apt update
[vagrant@ubuntu-bionic ~]$ sudo apt upgrade
```

## VS Code インストール

- [VS Code](https://azure.microsoft.com/ja-jp/products/visual-studio-code/)

![1](https://user-images.githubusercontent.com/1900544/85050069-80c61300-b1d0-11ea-8c3f-64c74cb5ebc2.PNG)

![2](https://user-images.githubusercontent.com/1900544/85050144-a4895900-b1d0-11ea-8b6f-1ac06c448a2f.PNG)

![3](https://user-images.githubusercontent.com/1900544/85050359-ee723f00-b1d0-11ea-851a-63f75ca29b49.PNG)

```
$ mkdir ~/epc
```


# SCTP

## pysctp
PythonからSCTPを扱うライブラリとして"pysctp"があるので、

- [https://github.com/P1sec/pysctp](https://github.com/P1sec/pysctp)

下記のコマンドで pysctp をインストールします。
```
$ pip install pysctp
```



# S1AP

## ASN.1

## asn1c

```
$ sudo apt install automake libtool bison flex git unzip make
$ cd ~
$ wget https://github.com/mouse07410/asn1c/archive/vlm_master.zip
$ unzip vlm_master.zip
$ cd asn1c-vlm_master
$ test -f configure || autoreconf -iv
$ ./configure
$ make
$ sudo make install
$ cd ..
$ rm -rf asn1c-vlm_master
$ rm vlm_master.zip
```

epc/ans1 に 36413-f80.asnを格納します
　
```
$ cd ~/epc/asn1
$ mkdir out
$ asn1c -D out -fcompound-names 36413-f80.asn
```


<!--stackedit_data:
eyJoaXN0b3J5IjpbMTcyOTIwMTg5LC0xMzMxODA4ODQxLDE2Nj
c3NTg4ODQsLTE1MzQ2MjI1MjgsNzYwNTk2ODkwLC02MDAwNzAy
MjMsNjc0MjI2MjEzLC00MDgwNzk0OTUsLTE4MTY2MDUzOTAsMT
g3NTY2OTI4NCwtMTk1MTI4MTU1MCwxMTg2ODIwNzE0LC05NDQ2
NTY5NDMsNTk5Njg2NzYsLTE4NTc4ODQ5MCwtMTUxMDY0ODk3Mi
wtOTM3MzE5NTk4LDE0NTE4MzYwNDgsNDk0NTcxMjIxLC0xMDg3
NjA2ODU3XX0=
-->