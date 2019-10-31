qiime diversity core-metrics-phylogenetic \
      --i-phylogeny rooted-tree.qza \
      --i-table table.qza \
      --p-sampling-depth !{params.samplingDepth} \
      --p-n-jobs !{task.cpus} \
      --m-metadata-file meta.tsv \
      --output-dir out
mv out/* -t .
