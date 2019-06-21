#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
import pysam
import collections
import argparse
from singlecellmultiomics.tagtools import tagtools
import pysamiterators.iterators as pysamIterators
import gzip
import pickle
import subprocess

import matplotlib
import matplotlib.lines as mlines
matplotlib.rcParams['figure.dpi'] = 160
matplotlib.use('Agg')
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import string
import math
import singlecellmultiomics.modularDemultiplexer
TagDefinitions = singlecellmultiomics.modularDemultiplexer.TagDefinitions


from singlecellmultiomics.statistic import PlateStatistic


if __name__=='__main__':
    argparser = argparse.ArgumentParser(
     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
     description='Visualize single cell statistics on a plate plot')
    argparser.add_argument('-o',  type=str, help="output plot folder path, every library will be visualised as a separate plate", default='./plots/')

    argparser.add_argument('alignmentfiles',  type=str, nargs='*')
    args = argparser.parse_args()

    if not os.path.exists(args.o):
        os.makedirs(args.o)

    ps = PlateStatistic(args)
    for alignmentFile in args.alignmentfiles:
        with pysam.AlignmentFile(alignmentFile) as f:
            for read in f:
                ps.processRead(read)

    ps.plot(args.o+'/PS')
