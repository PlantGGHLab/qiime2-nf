qiime dada2 denoise-paired !{params.denoiseExtra} \
      --i-demultiplexed-seqs demuxed.qza \
      --p-trunc-len-f !{params.truncF} \
      --p-trunc-len-r !{params.truncR} \
      --p-n-threads !{task.cpus} \
      --o-table feature-table.qza \
      --o-representative-sequences rep-seqs.qza \
      --o-denoising-stats denoising-stats.qza
