import requests
from urllib.parse import urlparse
import os

import sys, json
import re

board=None
kernel=None

argc=len(sys.argv)-1
if argc>0:
    board=sys.argv[1]
    if argc>1:
        kernel=sys.argv[2]

print(f"board  : {board}")
print(f"kernel : {kernel}")

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

uboot_data=download(uboot_release_url)
uj=json.loads(uboot_data)

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
            board_=re.sub('^(bpi-r[2346pro]+).*$',r'\1',ufname)
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
            branch=re.sub('^CI-BUILD-([56]\.[0-9]+-main).*$',r'\1',kname)
            #print("branch:",branch)
            rel["body"]=""
            if branch=='5.15-main' or branch=='6.1-main': #catch 5.15 for r2 for internal wifi-support
                #print("kernel-release",kname)
                if not branch in kfiles:
                    rdata={}
                    for kf in rel.get("assets"):
                        kfname=kf.get("name")
                        if re.search("^bpi-r.*\.tar.gz$",kfname):
                            board_=re.sub('^(bpi-r[2346pro]+).*$',r'\1',kfname)
                            #if not board in rdata:
                            #    rdata[board]={}
                            #rdata[board][kfname]=kf.get("browser_download_url")
                            rdata[board_]=kf.get("browser_download_url")
                    kfiles[branch]=rdata
            #print("release-data:",json.dumps(rel,indent=2))
    #print("files:",json.dumps(kfiles,indent=2))

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

conffile='sourcefiles_'+board+'.conf'
if ufile:
    a = urlparse(ufile)
    fname=os.path.basename(a.path)
    print(f"ubootfile: {ufile} filename: {fname}")
    if not os.path.isfile(fname):
        download(ufile,fname)
    else: print(fname,"already exists")
    with open(conffile, 'w') as f:
        f.write("imgfile="+fname+'\n')

if kfile:
    a = urlparse(kfile)
    fname=os.path.basename(a.path)
    print(f"kernelfile: {kfile} filename: {fname}")
    if not os.path.isfile(fname):
        download(kfile,fname)
    else: print(fname,"already exists")
    with open(conffile, 'a') as f:
        f.write("kernelfile="+fname+'\n')
