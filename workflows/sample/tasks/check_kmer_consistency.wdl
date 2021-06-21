version 1.0

task check_kmer_consistency {
  input {
    String log_name = "check_kmer_consistency.log"
    File ref_modimers #= config['ref']['modimers'],
    File movie_modimers #= expand(f"samples/{sample}/jellyfish/{{movie}}.modimers.tsv.gz", movie=movies)

    String kmerconsistency_txt_name = "kmerconsistency.txt" #: f"samples/{sample}/jellyfish/{sample}.kmerconsistency.txt"
    String pb_conda_image

    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate base_python3
    echo "$(conda info)"
    
    (python3 /opt/pb/scripts/check_kmer_consistency.py ~{ref_modimers} ~{movie_modimers} > ~{kmerconsistency_txt_name}) > ~{log_name} 2>&1
  >>>
  output {
    File kmerconsistency_txt = "~{kmerconsistency_txt_name}"
    File log = "~{log_name}"
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
