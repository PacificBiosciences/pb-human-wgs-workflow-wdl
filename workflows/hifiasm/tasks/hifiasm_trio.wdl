version 1.0

import "../../common/structs.wdl"
import "hifiasm.wdl" as hifiasm
import "gfa_asm_single.wdl" as gfa_asm_single

task hifiasm_trio_assemble {
  input {
    Int threads = 48
    String sample_name
    String prefix = "~{sample_name}.asm"
    String log_name = "hifiasm.log"
    File parent1_yak
    File parent2_yak

    Array[File] movie_fasta

    String pb_conda_image

  }

  String extra = "-c1 -d1"

  Float multiplier = 2
  Int disk_size = ceil(multiplier * size(movie_fasta, "GB")) + 20
#  Int disk_size = 200
  Int memory = threads * 3              #forces at least 3GB RAM/core, even if user overwrites threads

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate hifiasm
    echo "$(conda info)"

    (hifiasm -o ~{prefix} -t ~{threads} ~{extra} -1 ~{parent1_yak} -2 ~{parent2_yak} ~{sep=" " movie_fasta} \
    && echo -e "hap1\t~{parent1_yak}\nhap2\t~{parent2_yak}" > ~{prefix}.key.txt) > ~{log_name} 2>&1
  >>>
  output {
    File hap1_p_ctg        = "~{prefix}.dip.hap1.p_ctg.gfa"
    File hap1_p_ctg_lowQ   = "~{prefix}.dip.hap1.p_ctg.lowQ.bed"
    File hap1_p_noseq      = "~{prefix}.dip.hap1.p_ctg.noseq.gfa"
    File hap2_p_ctg        = "~{prefix}.dip.hap2.p_ctg.gfa"
    File hap2_p_ctg_lowQ   = "~{prefix}.dip.hap2.p_ctg.lowQ.bed"
    File hap2_p_noseq      = "~{prefix}.dip.hap2.p_ctg.noseq.gfa"
    File p_utg_noseq       = "~{prefix}.dip.p_utg.noseq.gfa"
    File p_utg_lowQ        = "~{prefix}.dip.p_utg.lowQ.bed"
    File r_utg_noseq       = "~{prefix}.dip.r_utg.noseq.gfa"
    File r_utg_lowQ        = "~{prefix}.dip.r_utg.lowQ.bed"
    File key               = "~{prefix}.key.txt"

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


workflow hifiasm_trio {
  input {
    String sample_name

    Array[File] movie_fasta

    Array[String] parent_names
    IndexedData target
    String? reference_name
    String pb_conda_image
    Pair[String,File] yak_parent1
    Pair[String,File] yak_parent2
    Boolean trioeval
    Boolean triobin    
  }

  Int num_parents = length(parent_names)
  Boolean trio = if num_parents == 2 then true else false
  if (trio) {  
    call hifiasm_trio_assemble {
      input:
        sample_name = sample_name,
        movie_fasta = movie_fasta,
        parent1_yak = yak_parent1.right,
        parent2_yak = yak_parent2.right,
        pb_conda_image = pb_conda_image
    }

    call gfa_asm_single.gfa_asm_single as gfa_asm_hap1_p_ctg {
      input:
        gfa = hifiasm_trio_assemble.hap1_p_ctg,
        index = target.indexfile,
        pb_conda_image = pb_conda_image
    }

    call gfa_asm_single.gfa_asm_single as gfa_asm_hap2_p_ctg {
      input:
        gfa = hifiasm_trio_assemble.hap2_p_ctg,
        index = target.indexfile,
        pb_conda_image = pb_conda_image
    }

   if (trioeval) {
      call yak_trioeval as yak_trioeval_hap1_p_ctg  {
        input:
          fasta_gz = gfa_asm_hap1_p_ctg.fasta_gz,
          parent1_yak = yak_parent1.right,
          parent2_yak = yak_parent2.right,
          pb_conda_image = pb_conda_image
      }

      call yak_trioeval as yak_trioeval_hap2_p_ctg  {
        input:
          fasta_gz = gfa_asm_hap2_p_ctg.fasta_gz,
          parent1_yak = yak_parent1.right,
          parent2_yak = yak_parent2.right,
          pb_conda_image = pb_conda_image
      }
    }

    if (triobin) {
      call yak_triobin as yak_triobin_hap1_p_ctg  {
        input:
          fasta_gz = gfa_asm_hap1_p_ctg.fasta_gz,
          parent1_yak = yak_parent1.right,
          parent2_yak = yak_parent2.right,
          pb_conda_image = pb_conda_image
      }

      call yak_triobin as yak_triobin_hap2_p_ctg  {
        input:
          fasta_gz = gfa_asm_hap2_p_ctg.fasta_gz,
          parent1_yak = yak_parent1.right,
          parent2_yak = yak_parent2.right,
          pb_conda_image = pb_conda_image
      }
    }


    call hifiasm.align_hifiasm {
      input:
        sample_name = sample_name,
        target = target,
        reference_name = reference_name,
        query = [
          gfa_asm_hap1_p_ctg.fasta_gz,
          gfa_asm_hap2_p_ctg.fasta_gz
        ],
        pb_conda_image = pb_conda_image
    }
  }
  
  output {
  }
}

