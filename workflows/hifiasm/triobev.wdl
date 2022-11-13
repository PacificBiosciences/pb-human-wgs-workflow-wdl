version 1.0

#This new workflow is used to run yak_triobin and yak_trioeval for memory size testing, coded by Charlie Bi

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
  Int memory = threads * 5              #forces at least 5GB RAM/core, even if user overwrites threads

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
  Int memory = threads * 5              #forces at least 5GB RAM/core, even if user overwrites threads

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

workflow triobev {
  input {
    Pair[String,File] yak_parent1
    Pair[String,File] yak_parent2
    File fasta_hap1_p_ctg_gz
    File fasta_hap2_p_ctg_gz
    String pb_conda_image
    Boolean triobin
    Boolean trioeval
  }

   if (trioeval) {
     call yak_trioeval as yak_trioeval_hap1_p_ctg  {
       input:
         fasta_gz = fasta_hap1_p_ctg_gz,
         parent1_yak = yak_parent1.right,
         parent2_yak = yak_parent2.right,
         pb_conda_image = pb_conda_image
     }

     call yak_trioeval as yak_trioeval_hap2_p_ctg  {
       input:
         fasta_gz = fasta_hap2_p_ctg_gz,
         parent1_yak = yak_parent1.right,
         parent2_yak = yak_parent2.right,
         pb_conda_image = pb_conda_image
      }
    }

    if (triobin) {
      call yak_triobin as yak_triobin_hap1_p_ctg  {
        input:
          fasta_gz = fasta_hap1_p_ctg_gz,
          parent1_yak = yak_parent1.right,
          parent2_yak = yak_parent2.right,
          pb_conda_image = pb_conda_image
      }

      call yak_triobin as yak_triobin_hap2_p_ctg  {
        input:
          fasta_gz = fasta_hap2_p_ctg_gz,
          parent1_yak = yak_parent1.right,
          parent2_yak = yak_parent2.right,
          pb_conda_image = pb_conda_image
      }
    } 
     output {
  }
}
