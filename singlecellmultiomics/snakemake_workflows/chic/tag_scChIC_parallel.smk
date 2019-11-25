from singlecellmultiomics.libraryDetection.sequencingLibraryListing import SequencingLibraryLister
from glob import glob
import collections
from singlecellmultiomics.utils import get_contig_list_from_fasta

"""
This workflow:
    Starts off from a folder containing fastq files
    - Detects libraries
    - Demultiplexes per library, automatically detecting the right barcodes
    - [trims] @ todo
    - Maps, sorts and indexes the reads per library
    - Deduplicates and identifies molecules
    - Creates QC plots
"""

configfile: "scmo_scCHiC_config.json"

# This code detects which libraries are present in the current folder:
l = SequencingLibraryLister()
LIBRARIES = l.detect(glob('*.fastq.gz'), merge='_')
# Flatten:
fastq_per_lib = collections.defaultdict(list)
for lib,lane_dict in LIBRARIES.items():
    for lane,read_dict in lane_dict.items():
        fastq_per_lib[lib] += read_dict['R1']
        fastq_per_lib[lib] += read_dict['R2']
libraries =  list( fastq_per_lib.keys() )
###

# Obtain contigs:
contigs = get_contig_list_from_fasta(config['reference_file'])
# If you are unhappy about the contigs SCMO provides decide on your own on the next line (uncomment):
# contigs = ['chr1','chr2']


def get_fastq_file_list(wildcards):
    # Obtain a list of fastq files associated to wildcards.library
    global libraries
    return sorted( fastq_per_lib[wildcards.library] )

def get_target_demux_list():
    global libraries
    targets = []
    for lib in libraries:
        targets.append('processed/' + lib + "/demultiplexedR1.fastq.gz" )
        targets.append('processed/' + lib + "/demultiplexedR2.fastq.gz" )
    return targets

def get_target_tagged_bam_list():
    return [f"processed/{library}/tagged.bam" for library in libraries]

rule all:
    input:
        # get_target_demux_list() use this for demux only
        get_target_tagged_bam_list()

rule SCMO_demux:
    input:
        fastqfiles = get_fastq_file_list
    output:
        "processed/{library}/demultiplexedR1.fastq.gz",
        "processed/{library}/demultiplexedR2.fastq.gz"
    shell:
        "demux.py -merge _ {input.fastqfiles} -o processed --y"

rule bwa_map:
    input:
        config['reference_file'],
        "processed/{library}/demultiplexedR1.fastq.gz",
        "processed/{library}/demultiplexedR2.fastq.gz"
    output:
        "processed/{library}/sorted.bam"
    shell:
        "bwa mem -t 16 {input} |  samtools view -bS - | \
        samtools sort -@ 16 -m 7G - -o {output}; samtools index {output}"


rule SCMO_tagmultiome_ChiC_parallel_scatter:
    input:
        bam = "processed/{library}/sorted.bam"

    output:
        "processed/{library}/TEMP_CONTIG/{contig}.bam"
    shell:
        "bamtagmultiome.py -method chic -contig {wildcards.contig} {input.bam} -o {output}"


rule SCMO_tagmultiome_ChiC_parallel_gather:
    input:
        chr_bams =  expand("processed/{{library}}/TEMP_CONTIG/{contig}.bam", contig=contigs)
    message:
        'Merging contig BAM files'
    output:
        "processed/{library}/tagged.bam"
    shell:
        "samtools merge -c {output} {input.chr_bams}; samtools index {output}"


rule SCMO_library_stats:
    input:
        bam = "processed/{library}/tagged.bam"
    output:
        "processed/{library}/plots/ReadCount.png"
    shell:
        "libraryStatistics.py processed/{library} -tagged_bam /tagged.bam"

rule SCMO_count_table
    input:
        bam = "processed/{library}/tagged.bam"
    output:
        "processed/{library}/count_table_{config.counting_bin_size}"
    shell:
        "bamToCountTable.py -minMQ {config.counting_min_mq} processed/{library} -tagged_bam /tagged.bam"

        bamToCountTable.py --filterXA ./tagged/sorted.bam -o ./count_table.csv
-joinedFeatureTags reference_name -sampleTags SM -bin 250_000 -binTag DS --dedup