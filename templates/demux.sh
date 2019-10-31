qiime cutadapt demux-paired !{params.demuxExtra} \
      --i-seqs seqs.qza\
      --m-forward-barcodes-file meta.tsv \
      --m-forward-barcodes-column barcode-fwd \
      --m-reverse-barcodes-file meta.tsv \
      --m-reverse-barcodes-column barcode-rev \
      --o-per-sample-sequences demuxed-seqs.qza \
      --o-untrimmed-sequences untrimmed-seqs.qza
