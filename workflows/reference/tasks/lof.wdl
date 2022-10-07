version 1.0

task generate_lof_lookup {
  input {
    String url
    String log_name = "generate_lof_lookup.log"
    String lof_lookup_name = "lof_lookup.txt"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    (zcat ~{url} | cut -f 1,21,24 | tail -n+2 \
        | awk "{{ printf(\\"%s\\tpLI=%.3g;oe_lof=%.5g\\n\\", \$1, \$2, \$3) }}" > ~{lof_lookup_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File lof_lookup = "~{lof_lookup_name}"
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
