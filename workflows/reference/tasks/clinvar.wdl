version 1.0

task generate_clinvar_lookup {
  input {
    String url
    String log_name = "generate_clinvar_lookup.log"
    String clinvar_lookup_name = "clinvar_gene_desc.txt"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    (cut -f 2,5 ~{url} | grep -v ^$'\t' > ~{clinvar_lookup_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File clinvar_lookup = "~{clinvar_lookup_name}"
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
