version 1.0

task yak_trioeval {
  input {
    Int threads = 16
    File fasta_gz
    String yak_trioeval_txt_name = "~{basename(fasta_gz)}.trioeval.txt"
    String log_name = "yak.fasta.trioeval.log"
    File parent1_yak
    File parent2_yak
    String pb_conda_image
  }

  Float multiplier = 2
  Int disk_size = ceil(multiplier * size(fasta_gz, "GB")) + 20
#  Int disk_size = 200
  Int memory = threads * 3              #forces at least 3GB RAM/core, even if user overwrites threads

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate yak
    echo "$(conda info)"

    (yak trioeval  -t ~{threads} ~{parent1_yak} ~{parent2_yak} ~{fasta_gz}> ~{yak_trioeval_txt_name} ) > ~{log_name} 2>&1
  >>>
  output {
    File yak_trioeval_file_name  = "~{yak_trioeval_txt_name}"

    File log = "~{log_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "~{memory}" + " GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

task yak_triobin {
  input {
    Int threads = 16
    File fasta_gz
    String yak_triobin_txt_name = "~{basename(fasta_gz)}.triobin.txt"
    String log_name = "yak.fasta.triobin.log"
    File parent1_yak
    File parent2_yak
    String pb_conda_image
  }

  Float multiplier = 2
  Int disk_size = ceil(multiplier * size(fasta_gz, "GB")) + 20
#  Int disk_size = 200
  Int memory = threads * 3              #forces at least 3GB RAM/core, even if user overwrites threads

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate yak
    echo "$(conda info)"

    (yak triobin  -c1 -d1 -t ~{threads} ~{parent1_yak} ~{parent2_yak} ~{fasta_gz} > ~{yak_triobin_txt_name} ) > ~{log_name} 2>&1
  >>>
  output {
    File yak_triobin_file_name  = "~{yak_triobin_txt_name}"

    File log = "~{log_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "~{memory}" + " GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}
