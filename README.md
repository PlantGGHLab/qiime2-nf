# qiime2-nf

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A519.07.0-brightgreen.svg)](https://www.nextflow.io/)

Microbiome analysis with [QIIME2](https://qiime2.org/)

## Getting started
1. Install [`nextflow`](https://www.nextflow.io), either directly or with `conda`
1. Install one of [`docker`](https://docs.docker.com/engine/installation/), [`singularity`](https://www.sylabs.io/guides/3.0/user-guide/), or [`conda`](https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html)
1. In a new directory, write your configurations to the file `nextflow.config`. See [Example config](#example-config).
1. Execute the workflow

   `nextflow run -resume Liulab/qiime2-nf`

For more details on running `nextflow`, run `nextflow help`.

### Using [`slurm`](https://slurm.schedmd.com/)
Simply tell `nextflow` to use the `slurm` profile. Multiple profiles can be
specified together, separated by a comma. For example:

~~~bash
nextflow run -resume Liulab/qiime2-nf -profile docker,slurm
~~~

### Beocat
On KSU's Beocat, `singularity` and `slurm` are available. It's recommended to use the provided profiles:

~~~bash
nextflow run -resume Liulab/qiime2-nf -profile singularity,slurm
~~~

## Input
The input is expected to be a pair of gziped fastq for the forward and reverse
read sequences, and a text file listing the samples barcode.

### Default location

By default, the pipeline will look for fastq files with `R1` and `R2` in their
name under the `data/` subdirectory (relative to the current working directory).
It will also look for any file with the `.txt` extension to use as the barcodes file.

You can either prepare your data according to this default or change where to
find the data with the `reads` and `barcode` parameters. See [Optional pipeline
parameters](#optional-pipeline-parameters).

### Barcode format

The barcode file contain 4 tab-separated columns. These are the string
`barcode`, the forward sequence, the reverse sequence, and the sample ID,
respectively. For example:

~~~
barcode	GGATCGTAATAC	GATTATCGACGA	1AA
barcode	GGTTATTTGGCG	GTCGTGTAGCCT	1AB
barcode	CGTGATCCGCTA	ATCGCACAGTAA	1AE
~~~

## Configuration
### Required parameters
There are two steps in the pipeline that require parameters based on the results
of previous steps. Initially, when these parameters are unspecified, the
pipeline will halt, reporting an error. This is expected, just add the required parameter(s) and
rerun the pipeline (make sure to specify `-resume`). The pipeline will proceed
from where it stopped previously.

See ["Moving Pictures" tutorial](https://docs.qiime2.org/2019.7/tutorials/moving-pictures)
for how to pick an appropriate value for these parameters. The relevant output files will be found in `v11nDir`
(default: `out/visualization`), and `rawDir` (default: `out/raw-data`).

#### For Denoising
Two parameters are required for this step
- `truncF` is the position at which the forward sequences should be
  truncated due to a drop-off in quality.
- `truncR` is the position at which the reverse sequences should be
  truncated due to a drop-off in quality.

#### For Core Metrics Analysis
One parameter (`samplingDepth`) is required during the alpha and beta diversity
analysis process. This is the total frequency that each sample should be
rarefied to prior to computing the diversity metrics.

### Optional QIIME2 parameters
Some of the underlying QIIME2 plugins also take optional parameters. Below is a
list of the parameter name to use for each step and where to find documentation
for these params.

- demultiplexing: `demuxExtra` [cutadapt docs][cutadapt-docs]
- summarizing demultiplexed sequences: `demuxSumExtra` [demux docs][demux-docs]
- denoising: `denoiseExtra` [dada2 docs][dada2-docs]
- visualizing the denoisig stats: `visualizeDenoiseStatsExtra` [metadata docs][metadata-docs]
- building phylogenetic trees: `phylogenyExtra` [phylogeny docs][phylogeny-docs]
- classifying taxonomy: `taxonomyClassificationExtra` [feature-classifier docs][classifier-docs]
- visualizing taxonomy: `visualizeTaxonomyExtra` [metadata docs][metadata-docs]

### Optional pipeline parameters
- `reads`: wildcard pattern to look for input reads
  (default: `"data/*R{1,2}*.fastq{,.gz}"`)
- `barcode`: pattern to look for the barcode file (default: `"data/*.txt"`)
- `classifier`: ML model to use for taxonomy classification
  (default: `https://data.qiime2.org/2019.7/common/gg-13-8-99-515-806-nb-classifier.qza`)
- `prefix`: prefix to add to output files (default: name of the current working directory)
- `outdir`: output directory
- `v11nDir`: QIIME2 visualizations directory (default: `${outdir}/visualization`)
- `rawDir`: raw data from QIIME2 artifacts directory (default: `${outdir}/raw-data`)

### Multithreading
Some tasks in the pipeline can make use of multiple cores. These are tagged with
the label `multithreaded` inside the main pipeline script. By default, these
processes run with a single core. In order to allocate more cores, add the
following snippet to `nextflow.config`, replacing `4` with the number of cores to
use.

~~~nextflow
process { withLabel: multithreaded { cpus = 4 } }
~~~

### Example config 
~~~nextflow
/* nextflow.config */
params {
    // Customize where to find the input
    reads = "sample-r{1,2}.fq.gz"
    barcode = "barcode.txt"
    // Customize prefix for output files
    prefix = "my-awesome-project"
    classifier = "https://data.qiime2.org/2019.7/common/silva-132-99-nb-classifier.qza"
    // Extra parameter for qiime
    taxonomyClassificationExtra = "--p-confidence 0.8"
    truncF = 200
    truncR = 210
    samplingDepth = 5000
}
process {
    // Set processes tagged with multithreaded to use more threads
    withLabel: multithreaded {
        cpus = 12
    }
    // Customize resource for a specific step
    withName: buildPhylogeneticTrees {
        memory = 32.GB
    }
}
// Change where to save conda environment(s)
conda.cacheDir = "/home/bob/nextflow-conda-envs"
// Send a notification email when the pipeline terminates
notification.enabled = true
notification.to = "bob@example.com"
~~~

See [Configuration](https://www.nextflow.io/docs/latest/config.html) for more
details.

## Output
QIIME2 produces two types of output `artifact` (`.qza`) and `visualization`
(`.qzv`). You can either interact with these files using the QIIME2 provided
[CLI](https://docs.qiime2.org/2019.7/interfaces/q2cli/), and
[artifact API](https://docs.qiime2.org/2019.7/interfaces/artifact-api/).

Underneath, these files are really just zip archives that contains the data and
some additional metadata/information. You can use `unzip` to unpack the file and
inspect its content directly.

## Common Issues
### Nextflow fails to download file from an https source with the error `javax.net.ssl.SSLHandshakeException: Received fatal alert: handshake_failure`
1. Download the Java Cryptography Extension(JCE) zip file for Java 8 from
   [here][jce].
1. Uncompress the downloaded archive
1. Move `local_policy.jar` and `US_export_policy.jar` to
   `$JAVA_HOME/jre/lib/security`. If there is no `jre/` subdirectory under
   `$JAVA_HOME/`, move to `$JAVA_HOME/lib/security` instead

[jce]: https://www.oracle.com/technetwork/java/javase/downloads/jce-all-download-5170447.html
[cutadapt-docs]: https://docs.qiime2.org/2019.7/plugins/available/cutadapt/demux-paired/
[demux-docs]: https://docs.qiime2.org/2019.7/plugins/available/demux/summarize/
[dada2-docs]: https://docs.qiime2.org/2019.7/plugins/available/dada2/denoise-paired/
[metadata-docs]: https://docs.qiime2.org/2019.7/plugins/available/metadata/tabulate/
[phylogeny-docs]: https://docs.qiime2.org/2019.7/plugins/available/phylogeny/align-to-tree-mafft-fasttree/
[classifier-docs]: https://docs.qiime2.org/2019.7/plugins/available/feature-classifier/classify-sklearn/
