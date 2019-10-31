nextflow.preview.dsl = 2

/*
 * Helper functions
 */
// Shortcut to create a value channel from a single file
// e.g. Channel.file("/path/to/file") is same as
// Channel.value(file("/path/to/file"))
Channel.metaClass.static.file = { f -> delegate.value(file(f)) }
canonicalize = { name -> "${prefix}-${name}" }

/*
 * Parameters Setup
 */
if (!params.dataDir)
    params.dataDir = "${PWD}/data"
if (!params.reads)
    params.reads = "${params.dataDir}/*R{1,2}*.fastq{,.gz}"
if (!params.barcode)
    params.barcode = "${params.dataDir}/*.txt"

if (!params.v11nDir)
    params.v11nDir = "${params.outdir}/visualization"
if (!params.rawDir)
    params.rawDir = "${params.outdir}/raw-data"

prefix = file(params.prefix?:PWD).name
classifier = Channel.file(params.classifier)

/*
 * Process Definitions
 */
process prepMetadata {
    input: file "barcode.txt"
    output: file "meta.tsv"
    shell: "prep-metadata.awk <barcode.txt >meta.tsv"
}

process importReads {
    input: set "forward.fastq.gz", "reverse.fastq.gz"
    output: file "seqs.qza"
    shell:
    """
    qiime tools import \
        --type MultiplexedPairedEndBarcodeInSequence \
        --input-path ./ \
        --output-path seqs.qza
    """
}

process demuxSeqs {
    input:
    file "seqs.qza"
    file "meta.tsv"
    output:
    file "demuxed-seqs.qza"
    file "untrimmed-seqs.qza"
    shell:
    template 'demux.sh'
}

process summarizeDemuxed {
    publishDir "${params.v11nDir}", saveAs: canonicalize
    input: file "demuxed.qza"
    output: file "demuxed.qzv"
    shell:
    """
    qiime demux summarize !{params.demuxSumExtra} \
          --i-data demuxed.qza \
          --o-visualization demuxed.qzv
    """
}

process exportDemuxSummary {
    publishDir "${params.rawDir}", saveAs: canonicalize
    input: file "demuxed.qzv"
    output: file "demuxed-seqs"
    shell: 'qiime tools export --input-path demuxed.qzv --output-path demuxed-seqs'
}

process denoiseSeqs {
    label 'multithreaded'
    memory { 1.5.GB * task.cpus }
    publishDir "${params.outdir}", saveAs: canonicalize
    input:
    file "demuxed.qza"
    file "phony"
    output:
    file "feature-table.qza"
    file "rep-seqs.qza"
    file "denoising-stats.qza"
    shell:
    if (params.truncF == null || params.truncR == null)
        error "Denoising parameters (truncF and truncR) (--p-trunc-len-f and --p-trunc-len-r required by qiime dada2 denoise-paired step) have not been defined."
    else
        template 'denoise.sh'
}

process summarizeFeatureTable {
    publishDir "${params.v11nDir}", saveAs: canonicalize
    input:
    file "table.qza"
    file "meta.tsv"
    output: file "feature-table.qzv"
    shell: template 'summarize-feature-table.sh'
}

process exportFeatureTableSummary {
    publishDir "${params.rawDir}", saveAs: canonicalize
    input: file "ft.qzv"
    output: file "feature-table"
    shell:
    'qiime tools export --input-path ft.qzv --output-path feature-table'
}

process visualizeRepSeqs {
    publishDir "${params.v11nDir}", saveAs: canonicalize
    input: file "rep-seqs.qza"
    output: file "rep-seqs.qzv"
    shell:
    """
    qiime feature-table tabulate-seqs \
          --i-data rep-seqs.qza \
          --o-visualization rep-seqs.qzv
    """
}

process visualizeDenoisingStats {
    publishDir "${params.v11nDir}", saveAs: canonicalize
    input: file "stats.qza"
    output: file "denoising-stats.qzv"
    shell:
    """
    qiime metadata tabulate !{params.visualizeDenoiseStatsExtra} \
          --m-input-file stats.qza \
          --o-visualization denoising-stats.qzv
    """
}

process buildPhylogeneticTrees {
    label 'multithreaded'
    memory { 1.GB * task.cpus }
    input: file "rep-seqs.qza"
    output:
    file "aligned-rep-seqs.qza"
    file "masked-aligned-rep-seqs.qza"
    file "unrooted-tree.qza"
    file "rooted-tree.qza"
    shell: template 'build-phylogenetic-trees.sh'
}

process getCoreMetrics {
    label 'multithreaded'
    publishDir "${params.outdir}", pattern: "*.qza", saveAs: canonicalize
    publishDir "${params.v11nDir}", pattern: "*.qzv", saveAs: canonicalize
    input:
    file "rooted-tree.qza"
    file "table.qza"
    file "meta.tsv"
    file "phony"
    output:
    file "*.{qza,qzv}"
    shell:
    if (params.samplingDepth == null)
        error "Sampling depth (--samplingDepth) not specified."
    else
        template 'get-core-metrics.sh'
}

process classifyTaxonomy {
    label 'multithreaded'
    memory { 1.5.GB * task.cpus }
    publishDir "${params.outdir}", saveAs: canonicalize
    input:
    file "classifier.qza"
    file "rep-seqs.qza"
    output: file "taxonomy.qza"
    shell: template 'classify.sh'
}

process visualizeTaxonomy {
    publishDir "${params.v11nDir}", saveAs: canonicalize
    input: file "taxonomy.qza"
    output: file "taxonomy.qzv"
    shell:
    """
    qiime metadata tabulate !{params.visualizeTaxonomyExtra} \
          --m-input-file taxonomy.qza \
          --o-visualization taxonomy.qzv
    """
}

process visualizeTaxonomyBarplot {
    publishDir "${params.v11nDir}", saveAs: canonicalize
    input:
    file "table.qza"
    file "taxonomy.qza"
    file "meta.tsv"
    output: file "taxa-bar-plots.qzv"
    shell: template 'plot-taxonomy.sh'
}
/*
 * Execution
 */

peReads = Channel.fromFilePairs(params.reads).collect { it[1] }

sequences = importReads(peReads)

metadata = Channel.fromPath(params.barcode) | first | prepMetadata

(demuxedSeqs, untrimmedSeqs) = demuxSeqs(sequences, metadata)

demuxedSeqsSummary = summarizeDemuxed(demuxedSeqs)
demuxedSeqsSummary | exportDemuxSummary

(featureTable, representativeSeqs, denoiseStats) =
    denoiseSeqs(demuxedSeqs, demuxedSeqsSummary)

(alignedSeqs, maskedAlignment, unrootedTree, rootedTree) =
    buildPhylogeneticTrees(representativeSeqs)

featureTableSummary = summarizeFeatureTable(featureTable, metadata)
featureTableSummary | exportFeatureTableSummary
getCoreMetrics(rootedTree, featureTable, metadata, featureTableSummary)

taxonomy = classifyTaxonomy(classifier, representativeSeqs)

// Summary & visualization
visualizeRepSeqs(representativeSeqs)
visualizeDenoisingStats(denoiseStats)
visualizeTaxonomy(taxonomy)
visualizeTaxonomyBarplot(featureTable, taxonomy, metadata)
