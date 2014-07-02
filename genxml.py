#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2013-2014
#
# Institut für Kernphysik, Universität Mainz    tel. +49 6131 39-25802
# 55128 Mainz, Germany                          fax  +49 6131 39-22964
#
# generate metadata required by the KPH 10y archive
#
# created by Michael O. Distler <distler@kph.uni-mainz.de>
#
# 30 Jun 2014; Michael O. Distler <distler@kph.uni-mainz.de>
#   added options: --noinflate, --nochecksums, and --committer

import argparse
import datetime
import sys
import os
import pwd
import grp
import cgi
import hashlib
from subprocess import Popen, PIPE
from pytz import timezone
import xml.dom.minidom as mdom

from collections import namedtuple
HashSize = namedtuple("HashSize", "hash sha size")

# calculate md5 checksum of a file
def md5sum(f, blocksize=65536):
    hash = hashlib.md5()
    sha = hashlib.sha224()
    size = 0
    while True:
        data = f.read(blocksize)
        if not data: break
        hash.update(data)
        sha.update(data)
        size += len(data)
    return HashSize(hash.hexdigest(), sha.hexdigest(), size)

def fixed_writexml(self, writer, indent="", addindent="", newl=""):
    # indent = current indentation
    # addindent = indentation to add to higher levels
    # newl = newline string
    writer.write(indent+"<" + self.tagName)

    attrs = self._get_attributes()
    a_names = attrs.keys()
    a_names.sort()

    for a_name in a_names:
        writer.write(" %s=\"" % a_name)
        mdom._write_data(writer, attrs[a_name].value)
        writer.write("\"")
    if self.childNodes:
        writer.write(">")
        if (len(self.childNodes) == 1 and
            self.childNodes[0].nodeType == mdom.Node.TEXT_NODE):
            self.childNodes[0].writexml(writer, '', '', '')
        else:
            writer.write(newl)
            for node in self.childNodes:
                node.writexml(writer, indent+addindent, addindent, newl)
            writer.write(indent)
        writer.write("</%s>%s" % (self.tagName, newl))
    else:
        writer.write("/>%s"%(newl))

#if PY_MAJOR_VERSION < 3
mdom.Element.writexml = fixed_writexml
#endif

# command line interface
parser = argparse.ArgumentParser(description='generate metadata required by the KPH 10y archive.')
parser.add_argument('files', metavar='path_to_file', nargs='+', help='file to be archived - path relative to base directory required')
parser.add_argument("-v", "--verbose", help="increase output verbosity",action="store_true")
parser.add_argument("--label", metavar='text', nargs=1, default=[''], help="use text as archive label")
parser.add_argument("--description", metavar='text', nargs=1, default=[''], help="use text as description")
parser.add_argument("--comment", metavar='text', nargs=1, default=[''], help="use text as comment")
parser.add_argument("--setup", metavar='text', nargs=1, default=[''], help="use text as setup name")
parser.add_argument("--committer", metavar='text', nargs=1, default=[''], help="full name and email address of the person who made the commit", required=True)
parser.add_argument("--user", metavar='text', nargs=1, default=[''], help="use text as user name")
parser.add_argument("--uid", metavar='num', default=-1, type=int, choices=range(0, 65536), help="use num as user id")
parser.add_argument("--group", metavar='text', nargs=1, default=[''], help="use text as group name")
parser.add_argument("--gid", metavar='num', default=-1, type=int, choices=range(0, 65536), help="use num as group id")
parser.add_argument("--tape-copies", metavar='num', default=2, type=int, choices=range(0, 5), help="number of requested tape copies")
parser.add_argument("--disk-copies", metavar='num', default=1, type=int, choices=range(0, 5), help="number of requested hard disk copies")
parser.add_argument("--nochecksums", help="do not generate checksums (but use existing MD5SUM file)",action="store_true")
parser.add_argument("--noinflate", help="do not inflate the file",action="store_true")
parser.add_argument("--nocompression", help="no compression, leave the file as it is",action="store_true")
parser.add_argument("--gzip", metavar='level', default=-1, type=int, choices=range(0, 10), help="apply gzip compression to file (deprecated)")
parser.add_argument("--bzip2", metavar='level', default=-1, type=int, choices=range(0, 10), help="apply bzip2 compression to file (deprecated)")
parser.add_argument("--xz", metavar='level', default=-1, type=int, choices=range(0, 10), help="apply xz compression to file")
args = parser.parse_args()
#print(args)
#sys.exit()

# loop over all files
for fname in args.files:
    if os.path.isdir(fname):
        print("skip directory '"+fname+"'")
        continue
    if not os.path.isfile(fname):
        print("skip broken link '"+fname+"'")
        continue
    root,ext = os.path.splitext(fname)
    head,tail = os.path.split(fname)
    if ext == ".tgz": root += ".tar"; ext = ".gz"
    if ext == ".tbz": root += ".tar"; ext = ".bz2"
    if ext == ".tbz2": root += ".tar"; ext = ".bz2"
    if ext == ".txz": root += ".tar"; ext = ".xz"
    if ext == ".tlz": root += ".tar"; ext = ".lzma"
    if ext not in ('.gz', '.bz2', '.xz', '.lzma', '.Z', '.z'):
        root += ext; ext = ''
        
    if args.nocompression:
        xmlpath=fname+".xml"
    else:
        xmlpath=root+".xml"
            
    #print(root,ext,head,tail,xmlpath)
    if os.path.exists(xmlpath):
        print("can't overwrite existing metadata '"+xmlpath+"'")
        continue
    
    doc = mdom.Document()	# create minidom-document

    file = doc.createElement('file')	# create base element
    doc.appendChild(file)

    # add element 'path'
    if head == "":
        print("WARNING: path for file '"+fname+"' is empty")
    else:
        path = doc.createElement('path')
        path_content = doc.createTextNode(head)
        path.appendChild(path_content)
        file.appendChild(path)

    # add element 'name'
    name = doc.createElement('name')
    name_content = doc.createTextNode(tail)
    name.appendChild(name_content)
    file.appendChild(name)

    # add element 'committer'
    if args.committer[0]:
        committer = doc.createElement('committer')
        committer_content = doc.createTextNode(args.committer[0])
        committer.appendChild(committer_content)
        file.appendChild(committer)

    # add element 'compression'
    zip = doc.createElement('compression')
    if args.nocompression:
        zip_content = doc.createTextNode("none")
    elif args.xz>=0:
        zip_content = doc.createTextNode("xz")
        zip.setAttribute('level',str(args.xz))
    elif args.gzip>=0:
        zip_content = doc.createTextNode("gzip")
        zip.setAttribute('level',str(args.gzip))
    elif args.bzip2>=0:
        zip_content = doc.createTextNode("bzip2")
        zip.setAttribute('level',str(args.bzip2))
    else:
        zip_content = doc.createTextNode("auto")
    zip.appendChild(zip_content)
    file.appendChild(zip)
    
    # add element 'copies'
    copies = doc.createElement('copies')
    copies.setAttribute('tape',str(args.tape_copies))
    copies.setAttribute('disk',str(args.disk_copies))
    file.appendChild(copies)

    # add element 'description'
    if args.description[0]:
        desc = doc.createElement('description')
        desc_content = doc.createTextNode(args.description[0])
        desc.appendChild(desc_content)
        file.appendChild(desc)

    # add element 'setup'
    if args.setup[0]:
        setup = doc.createElement('setup')
        setup_content = doc.createTextNode(args.setup[0])
        setup.appendChild(setup_content)
        file.appendChild(setup)

    # add element 'label'
    if args.label[0]:
        label = doc.createElement('label')
        label_content = doc.createTextNode(args.label[0])
        label.appendChild(label_content)
        file.appendChild(label)

    # add element 'comment'
    if args.comment[0]:
        comment = doc.createElement('comment')
        comment_content = doc.createTextNode(args.comment[0])
        comment.appendChild(comment_content)
        file.appendChild(comment)

    fstat = os.stat(fname)

    # add element 'size'
    size = doc.createElement('size')
    size_content = doc.createTextNode(str(fstat.st_size))
    size.appendChild(size_content)
    file.appendChild(size)

    cet = timezone("Europe/Berlin")
    # add element 'atime'
    atime = doc.createElement('atime')
    atime_content = doc.createTextNode(datetime.datetime.fromtimestamp(fstat.st_atime,cet).isoformat())
    atime.appendChild(atime_content)
    file.appendChild(atime)
    # add element 'ctime'
    ctime = doc.createElement('ctime')
    ctime_content = doc.createTextNode(datetime.datetime.fromtimestamp(fstat.st_ctime,cet).isoformat())
    ctime.appendChild(ctime_content)
    file.appendChild(ctime)
    # add element 'mtime'
    mtime = doc.createElement('mtime')
    mtime_content = doc.createTextNode(datetime.datetime.fromtimestamp(fstat.st_mtime,cet).isoformat())
    mtime.appendChild(mtime_content)
    file.appendChild(mtime)

    # add element 'owner'
    owner = doc.createElement('owner')
    if args.uid>=0:
        owner.setAttribute('uid',str(args.uid))
    else:
        owner.setAttribute('uid',str(fstat.st_uid))
    if args.user[0]:
        owner_content = doc.createTextNode(args.user[0])
    else:
        owner_content = doc.createTextNode(pwd.getpwuid(fstat.st_uid).pw_name)
    owner.appendChild(owner_content)
    file.appendChild(owner)
    
    # add element 'group'
    group = doc.createElement('group')
    if args.gid>=0:
        group.setAttribute('gid',str(args.gid))
    else:
        group.setAttribute('gid',str(fstat.st_gid))
    if args.group[0]:
        group_content = doc.createTextNode(args.group[0])
    else:
        group_content = doc.createTextNode(grp.getgrgid(fstat.st_gid).gr_name)
    group.appendChild(group_content)
    file.appendChild(group)

    # add element 'md5sum'
    if args.nochecksums:
        if os.path.isfile(head+'/MD5SUM'):
            with open(head+'/MD5SUM') as fp:
                for line in fp:
                    if line[34:len(line)-1] == tail:
                        md5 = doc.createElement('md5sum')
                        md5_content = doc.createTextNode(line[:32])
                        md5.appendChild(md5_content)
                        file.appendChild(md5)
    else:
        fobj = open(fname, "rb")
        hs = md5sum(fobj)
        fobj.close()
        #print(fstat.st_size, hs.size, hs.hash)
        md5 = doc.createElement('md5sum')
        md5_content = doc.createTextNode(hs.hash)
        md5.appendChild(md5_content)
        file.appendChild(md5)
        sha = doc.createElement('sha224')
        sha_content = doc.createTextNode(hs.sha)
        sha.appendChild(sha_content)
        file.appendChild(sha)

    # try to inflate files
    hs = ghs = bhs = lhs = None
    if not args.noinflate:
        try:
            import gzip
            fobj=gzip.open(fname, "rb")
            ghs = md5sum(fobj)
            fobj.close()
            #print(fstat.st_size, ghs.size, ghs.hash)
        except IOError:
            try:
                fnull = open(os.devnull, 'w')
                pipe = Popen(['gzip', '-dc', fname], stdout=PIPE, stderr=fnull)
                fobj=pipe.stdout
                ghs = md5sum(fobj)
                fobj.close()
                fnull.close()
                if ghs.size==0: ghs = None
                #print(fstat.st_size, ghs.size, ghs.hash)
            except:
                ghs = None
                #print("system gzip error:", sys.exc_info()[0])
        except:
            ghs = None
            print("gzip error:", sys.exc_info()[0])
    
        try:
            import bzip2
            fobj=bzip2.open(fname, "rb")
            bhs = md5sum(fobj)
            fobj.close()
            #print(fstat.st_size, bhs.size, bhs.hash)
        except ImportError:
            try:
                fnull = open(os.devnull, 'w')
                pipe = Popen(['bzip2', '-dc', fname], stdout=PIPE, stderr=fnull)
                fobj=pipe.stdout
                bhs = md5sum(fobj)
                fobj.close()
                fnull.close()
                if bhs.size==0: bhs = None
                #print(fstat.st_size, bhs.size, bhs.hash)
            except:
                bhs = None
                #print("system bzip2 error:", sys.exc_info()[0])
        except:
            bhs = None
            #print("bzip2 error:", sys.exc_info()[0])
    
        try:
            import lzma
            fobj=lzma.open(fname, "rb")
            lhs = md5sum(fobj)
            fobj.close()
            #print(fstat.st_size, lhs.size, lhs.hash)
        except ImportError:
            try:
                fnull = open(os.devnull, 'w')
                pipe = Popen(['xz', '-dc', fname], stdout=PIPE, stderr=fnull)
                fobj=pipe.stdout
                lhs = md5sum(fobj)
                fobj.close()
                fnull.close()
                if lhs.size==0: lhs = None
                #print(fstat.st_size, lhs.size, lhs.hash)
            except:
                lhs = None
                #print("system lzma error:", sys.exc_info()[0])
        except:
            lhs = None
            #print("lzma error:", sys.exc_info()[0])

    if ghs:    hs = ghs
    elif bhs:  hs = bhs
    elif lhs:  hs = lhs
    else:      hs = None

    # add element 'inflated'
    if hs:
        inflated = doc.createElement('inflated')	# create sub element
        rname = doc.createElement('name')
        rhead,rtail = os.path.split(root)
        rname.appendChild(doc.createTextNode(rtail))
        inflated.appendChild(rname)
        extent = doc.createElement('size')
        extent.appendChild(doc.createTextNode(str(hs.size)))
        inflated.appendChild(extent)
        hash = doc.createElement('md5sum')
        hash.appendChild(doc.createTextNode(hs.hash))
        inflated.appendChild(hash)
        hash2 = doc.createElement('sha224')
        hash2.appendChild(doc.createTextNode(hs.sha))
        inflated.appendChild(hash2)
        file.appendChild(inflated)

    # write xml file
    xml = open(xmlpath, "wb")
    xml.write(doc.toprettyxml(indent="  ", newl="\n", encoding="utf-8"))
    #xml.write(doc.toxml(encoding="utf-8"))
    xml.close()
