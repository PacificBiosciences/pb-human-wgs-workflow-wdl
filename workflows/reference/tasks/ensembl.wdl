version 1.0

task reformat_ensembl_gff {
  input {
    String url
    String log_name = "reformat_ensembl_gff.log"

    String ensembl_gff_name = "ensembl.GRCh38.101.reformatted.gff3.gz"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (zcat ~{url} \
        | awk -v OFS="\t" '{{ if ($1=="##sequence-region") && ($2~/^G|K/) {{ print $0; }} else if ($0!~/G|K/) {{ print "chr" $0; }} }}' \
        | bgzip > ~{ensembl_gff_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File ensembl_gff = "~{ensembl_gff_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}