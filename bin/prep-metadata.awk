#!/usr/bin/awk -f
# Script to convert barcode sequences into the metadata format expected by qiime2

BEGIN {
	OFS="\t";
	print "id", "barcode-fwd", "barcode-rev";
	print "#q2:types", "categorical", "categorical";
}

/^barcode/ {
	print $4, $2, $3;
}
