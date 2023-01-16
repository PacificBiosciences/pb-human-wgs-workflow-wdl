version 1.0

task gfa2stats {
  input {
    String log_gfa = "gfa2fa.log"
    String log_bgzip = "bgzip_fasta.log"
    String log_asm = "asm_stats.log"
    File gfa
    File index
    String fasta_name = "~{basename(gfa)}.fasta"
    String fasta_gz_name = "~{basename(gfa)}.fasta.gz"
    String fasta_stats_txt_name = "~{basename(gfa)}.fasta.gz.stats.txt"

    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = (ceil(multiplier * size(gfa, "GB")) + 20)*2

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate gfatools
    echo "$(conda info)"

    (gfatools gfa2fa ~{gfa} > ~{fasta_name}) 2> ~{log_gfa}

    conda activate htslib
    echo "$(conda info)"

    (bgzip --threads ~{threads} ~{fasta_name} -c > ~{fasta_gz_name}) > ~{log_bgzip} 2>&1

    conda activate k8
    echo "$(conda info)"

    (k8 /opt/pb/scripts/calN50/calN50.js -f ~{index} ~{fasta_gz_name} > ~{fasta_stats_txt_name}) > ~{log_asm} 2>&1
  >>>

  output {
    File fasta = "~{fasta_name}"
    File fasta_gz = "~{fasta_gz_name}"
    File fasta_stats_txt = "~{fasta_stats_txt_name}"
    File log1 = "~{log_gfa}"
    File log2 = "~{log_bgzip}"
    File log3 = "~{log_asm}"
  }

  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}
