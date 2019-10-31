qiime phylogeny align-to-tree-mafft-fasttree !{params.phylogenyExtra} \
      --i-sequences rep-seqs.qza \
      --p-n-threads !{task.cpus} \
      --o-alignment aligned-rep-seqs.qza \
      --o-masked-alignment masked-aligned-rep-seqs.qza \
      --o-tree unrooted-tree.qza \
      --o-rooted-tree rooted-tree.qza
