version 1.0

import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/hifiasm.wdl" as hifiasm

task yak_count {
  input {
    Int threads = 32
    String sample_name
    String log_name = "yak.count.log"

    Array[File] movie_fasta
    String pb_conda_image
  }

  Float multiplier = 2
  Int disk_size = ceil(multiplier * size(movie_fasta, "GB")) + 20
#  Int disk_size = 200
  Int memory = threads * 3              #forces at least 3GB RAM/core, even if user overwrites threads

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate yak
    echo "$(conda info)"

    (yak count -t {threads} -o ~{sample_name} ~{sep=" " movie_fasta})) > {log_name} 2>&1
  >>>
  output {
    File yak  = "~{sample_name}.yak"

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

workflow yak {
  input {
    String sample_name
    Array[IndexedData] sample
    String pb_conda_image
  }

  scatter (movie in sample) {
    call hifiasm.samtools_fasta as samtools_fasta {
      input:
        movie_fasta = movie,
        pb_conda_image = pb_conda_image
    }
  }


  call yak_count {
    input:
      sample_name = sample_name,
      movie_fasta = samtools_fasta.movie_fasta,
      pb_conda_image = pb_conda_image
  }

  output {
    Pair[String, File] yak_output = (sample_name, yak_count.yak)
    File log = yak_count.log
  }
}
