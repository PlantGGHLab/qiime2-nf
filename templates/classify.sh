qiime feature-classifier classify-sklearn !{params.taxonomyClassificationExtra} \
      --i-classifier classifier.qza \
      --i-reads rep-seqs.qza \
      --p-n-jobs !{task.cpus} \
      --o-classification taxonomy.qza
