import requests
from urllib.parse import urlparse
import os

import sys, json
import re

board=None
kernel=None
device="sdmmc"

argc=len(sys.argv)-1
if argc>0:
    board=sys.argv[1]
    if argc>1:
        kernel=sys.argv[2]
    if argc>2:
        device=sys.argv[3]

print(f"board  : {board}")
print(f"kernel : {kernel}")
print(f"device : {device}")

def read_settings(infile):
    config={}
    with open(infile) as f:
        for line in f:
            # ignore comments
            if line[0] == '#':
                continue
            key, value = line.split("=", 1)
            key = key.lower()
            config[key]=value.replace("\n", "")
    return config

config=None
conffile='sourcefiles_'+board+'.conf'
if os.path.isfile(conffile):
    config=read_settings(conffile)
    print(config)

def download(url, file_name=None):
    # get request
    response = requests.get(url)
    if file_name:
        # open in binary mode
        # write to file
        with open(file_name, "wb") as file:
            file.write(response.content)
    else:
        return response.content

uboot_release_url="https://api.github.com/repos/frank-w/u-boot/releases/latest"
kernel_releases_url="https://api.github.com/repos/frank-w/BPI-Router-Linux/releases"
bin_releases_url="https://api.github.com/repos/frank-w/arm-crosscompile/releases"

uboot_data=download(uboot_release_url)
uj=json.loads(uboot_data)

boardpattern='^(bpi-r[2346]+(pro|mini)?).*$'

if uj:
    ubootfiles={}
    uname=uj.get("name")
    #print("name:",uname)
    ufiles=uj.get("assets")
    #print("files:",json.dumps(ufiles,indent=2))
    for uf in ufiles:
        ufname=uf.get("name")
        if ufname.endswith("img.gz"):
            ufurl=uf.get("browser_download_url")
            board_=re.sub(boardpattern,r'\1',ufname)
            #print(board,ufurl)
            ubootfiles[board_]=ufurl
            #print("file:",json.dumps(uf,indent=2))

    #print("files:",json.dumps(ubootfiles,indent=2))

kernel_releases=download(kernel_releases_url)
krj=json.loads(kernel_releases)

if krj:
    kfiles={}
    for rel in krj:
        kname=rel.get("name")

        if re.search('CI-BUILD-.*-main',kname):
            branch=re.sub(r'^CI-BUILD-([56]\.[0-9]+-main).*$',r'\1',kname)
            #print("branch:",branch)
            rel["body"]=""
            if branch == kernel+'-main':
                #print("kernel-release",kname)
                if not branch in kfiles:
                    rdata={}
                    for kf in rel.get("assets"):
                        kfname=kf.get("name")
                        if re.search(r"^bpi-r.*\.tar.gz$",kfname):
                            board_=re.sub(boardpattern,r'\1',kfname)
                            #if not board in rdata:
                            #    rdata[board]={}
                            #rdata[board][kfname]=kf.get("browser_download_url")
                            rdata[board_]=kf.get("browser_download_url")
                    kfiles[branch]=rdata
            #print("release-data:",json.dumps(rel,indent=2))
    #print("files:",json.dumps(kfiles,indent=2))

bin_releases=download(bin_releases_url)
brj=json.loads(bin_releases)

if brj:
    bfiles={}
    for rel in brj:
        bname=rel.get("name")

        for f in rel.get("assets"):
            fname=f.get("name")

            if not fname in bfiles:
                if re.search(r"^(hostapd|iproute2).*\.tar.gz$",fname):
                    #fn=re.sub(boardpattern,r'\1',kfname)
                    bfiles[fname]=f.get("browser_download_url")

print("binfiles:",bfiles)

ufile=None
kfile=None

if board and board in ubootfiles:
    ufile=ubootfiles[board]
    print(f"board:{board} ubootfile: {ufile}")
    if kernel:
        if kernel+"-main" in kfiles:
            if board in kfiles[kernel+"-main"]:
                kfile=kfiles[kernel+"-main"][board]
                print(f"board:{board} kernelfile: {kfile}")
            else: print(f"board not in kfiles[kernel]")
        else: print(f"kernel not in kfiles")
    else: print(f"kernel not set!")
else: print(f"{board} not found in ubootfiles")

newconfig={}
if config and config.get("skipubootdownload"):
    newconfig["skipubootdownload"]=config.get("skipubootdownload")
    newconfig["imgfile"]=config.get("imgfile")
elif ufile:
    a = urlparse(ufile)
    fname=os.path.basename(a.path)
    print(f"ubootfile: {ufile} filename: {fname}")
    if os.path.isfile(fname):
        print(fname,"already exists")
        c=input('overwrite it [yn]? ').lower()
    else: c='y'
    if c=='y':
        download(ufile,fname)
    newconfig["imgfile"]=fname
else: print("no uboot image defined!")

if config and config.get("skipkerneldownload"):
    newconfig["skipkerneldownload"]=config.get("skipkerneldownload")
    newconfig["kernelfile"]=config.get("kernelfile")
elif kfile:
    a = urlparse(kfile)
    fname=os.path.basename(a.path)
    print(f"kernelfile: {kfile} filename: {fname}")
    if not os.path.isfile(fname):
        download(kfile,fname)
    else: print(fname,"already exists")
    newconfig["kernelfile"]=fname
else: print("no kernel defined!")


if config and config.get("replacehostapd"):
    newconfig["replacehostapd"]=config.get("replacehostapd")

    if bfiles:
        hostapdfile=bfiles.get("hostapd_arm64.tar.gz")
        a = urlparse(hostapdfile)
        fname=os.path.basename(a.path)
        print(f"hostapdfile: {hostapdfile} filename: {fname}")
        if not os.path.isfile(fname):
            download(hostapdfile,fname)
        else: print(fname,"already exists")
        newconfig["hostapdfile"]=fname
    else: print("no bfiles defined!")



with open(conffile, 'w') as f:
    for d in newconfig:
        s=d+'='+newconfig[d]
        f.write(s+'\n')
