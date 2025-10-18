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

config={}
conffile='sourcefiles_'+board+'.conf'
if os.path.isfile(conffile):
    config=read_settings(conffile)
    print(config)

newconfig = config.copy()

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

boardpattern='^(bpi-r[2346]+(pro|mini|lite)?).*$'

def getUbootInfo():
    uboot_release_url="https://api.github.com/repos/frank-w/u-boot/releases/latest"
    uboot_data=download(uboot_release_url)
    uj=json.loads(uboot_data)

    ubootfiles={}
    if uj:
        bl2files={}
        fipfiles={}
        uname=uj.get("name")
        #print("name:",uname)
        ufiles=uj.get("assets")
        #print("files:",json.dumps(ufiles,indent=2))
        for uf in ufiles:
            #print("file:",json.dumps(uf,indent=2))
            ufname=uf.get("name")
            if re.match(r'u-boot.*\.bin',ufname): continue
            ufurl=uf.get("browser_download_url")
            board_=re.sub(boardpattern,r'\1',ufname)
            device_=re.sub(r'^.*_(sdmmc|emmc|spim-nand|nor|ram).*$',r'\1',ufname)

            if not board_ in ubootfiles:
                ubootfiles[board_]={}
            if not device_ in ubootfiles[board_]:
                ubootfiles[board_][device_]={}
            if ufname.endswith("img.gz"):
                ubootfiles[board_][device_]={"name":ufname,"url":ufurl}
            elif device_=="ram" and ufname.endswith("bl2.bin"):
                if not "bl2" in ubootfiles[board_][device_]:
                    ubootfiles[board_][device_]["bl2"]={}
                if "8GB" in ufname:
                    if not "8G" in ubootfiles[board_][device_]["bl2"]:
                        ubootfiles[board_][device_]["bl2"]["8G"]={}
                    ubootfiles[board_][device_]["bl2"]["8G"]={"name":ufname,"url":ufurl}
                else:
                    ubootfiles[board_][device_]["bl2"]={"name":ufname,"url":ufurl}
            elif ufname.endswith("bl2.img"):
                print(ufname)
                if not "bl2" in ubootfiles[board_][device_]:
                    ubootfiles[board_][device_]["bl2"]={}
                if "8GB" in ufname:
                    if not "8G" in ubootfiles[board_][device_]["bl2"]:
                        ubootfiles[board_][device_]["bl2"]["8G"]={}
                    if "ubi" in ufname:
                        if not "UBI" in ubootfiles[board_][device_]["bl2"]:
                            ubootfiles[board_][device_]["bl2"]["UBI"]={}
                        ubootfiles[board_][device_]["bl2"]["8G"]["UBI"]={"name":ufname,"url":ufurl}
                    else:
                        ubootfiles[board_][device_]["bl2"]["8G"]["name"]=ufname
                        ubootfiles[board_][device_]["bl2"]["8G"]["url"]=ufurl
                elif "ubi" in ufname:
                    ubootfiles[board_][device_]["bl2"]["UBI"]={"name":ufname,"url":ufurl}
                else:
                    ubootfiles[board_][device_]["bl2"]["name"]=ufname
                    ubootfiles[board_][device_]["bl2"]["url"]=ufurl
            elif ufname.endswith("fip.bin"):
                ubootfiles[board_][device_]["fip"]={"name":ufname,"url":ufurl}
    return ubootfiles

ubootfiles=getUbootInfo()
print("files:",json.dumps(ubootfiles,indent=2))


def getKernelInfo():
    kernel_releases_url="https://api.github.com/repos/frank-w/BPI-Router-Linux/releases"
    kernel_releases=download(kernel_releases_url)
    krj=json.loads(kernel_releases)

    kfiles={}
    if krj:
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

    return kfiles

kfiles=getKernelInfo()
#print("files:",json.dumps(kfiles,indent=2))

def getBinInfo():
    bin_releases_url="https://api.github.com/repos/frank-w/arm-crosscompile/releases"
    bin_releases=download(bin_releases_url)
    brj=json.loads(bin_releases)

    bfiles={}
    if brj:
        for rel in brj:
            bname=rel.get("name")

            for f in rel.get("assets"):
                fname=f.get("name")

                if not fname in bfiles:
                    if re.search(r"^(hostapd|iproute2|iperf|wpa_supplicant).*\.tar.gz$",fname):
                        #fn=re.sub(boardpattern,r'\1',kfname)
                        bfiles[fname]=f.get("browser_download_url")
    return bfiles

bfiles=getBinInfo()
#print("binfiles:",bfiles)

def getInitrdInfo():
    releases_url="https://api.github.com/repos/frank-w/buildroot/releases"
    releases=download(releases_url)
    irj=json.loads(releases)

    #print("initrd releases:",json.dumps(irj,indent=2))

    ifiles={}
    if irj:
        for rel in irj:
            bname=rel.get("tag_name")

            for f in rel.get("assets"):
                fname=f.get("name")

                if not fname in ifiles:
                    if re.search(r"arm(hf|64).cpio.zst$",fname):
                        ifiles[fname]=f.get("browser_download_url")
    return ifiles

ifiles=getInitrdInfo()
print("initfiles:",ifiles)

ufile=None
kfile=None

if board and board in ubootfiles:
    #ufile=ubootfiles[board]
    ufile=ubootfiles[board][device] #={"bl2":{"name":ufname,"url":ufurl}}


    print(f"board:{board} ubootfile: {ufile}")
    if kernel:
        if kernel+"-main" in kfiles:
            b=board
            if b=="bpi-r3mini": b="bpi-r3"
            if b in kfiles[kernel+"-main"]:
                kfile=kfiles[kernel+"-main"][b]
                print(f"board:{board} kernelfile: {kfile}")
            else: print(f"board not in kfiles[kernel]")
        else: print(f"kernel not in kfiles")
    else: print(f"kernel not set!")
else: print(f"{board} not found in ubootfiles")

if not config.get("skipubootdownload") and ufile:
    if "mmc" in device:
        fname=ufile.get("name")
        a = urlparse(ufile.get("url"))
        #fname=os.path.basename(a.path)
        print(f"ubootfile: {ufile} filename: {fname}")
        if os.path.isfile(fname):
            print(fname,"already exists")
            c=input('overwrite it [yn]? ').lower()
        else: c='y'
        if c=='y':
            download(ufile.get("url"),fname)
            newconfig["imgfile"]=fname
    elif device in ['spim-nand','nor']:
        bl2=ufile.get("bl2")
        fip=ufile.get("fip")
        if bl2:
            download(bl2.get("url"),bl2.get("name"))
            newconfig["bl2file"]=bl2.get("name")
        if fip:
            download(fip.get("url"),fip.get("name"))
            newconfig["fipfile"]=fip.get("name")
else: print("no uboot image defined!")

if not config.get("skipkerneldownload") and kfile:
    a = urlparse(kfile)
    fname=os.path.basename(a.path)
    print(f"kernelfile: {kfile} filename: {fname}")
    if not os.path.isfile(fname):
        download(kfile,fname)
    else: print(fname,"already exists")
    newconfig["kernelfile"]=fname
else: print("no kernel defined!")

for replacement in ["hostapd","wpa_supplicant","iperf","iproute2"]:
    if config and config.get("replace"+replacement):
        newconfig["replace"+replacement]=config.get("replace"+replacement)

        if bfiles:
            replacefile=bfiles.get(replacement+"_arm64.tar.gz")
            a = urlparse(replacefile)
            fname=os.path.basename(a.path)
            print(f"{replacement}file: {replacefile} filename: {fname}")
            download(replacefile,fname)
            newconfig[replacement+"file"]=fname
        else: print("no bfiles defined!")

if not config.get("skipinitrddownload") and ifiles:
    if device in ["spim-nand","nor"]:
        fname="rootfs_arm64.cpio.zst"
        if fname in ifiles:
            print(f"initrd-file: {fname}")
            download(ifiles.get(fname),fname)
            newconfig["initrd"]=fname

with open(conffile, 'w') as f:
    for d in newconfig:
        s=d+'='+newconfig[d]
        f.write(s+'\n')
