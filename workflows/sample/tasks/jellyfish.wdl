version 1.1

task jellyfish_merge {
  input {
    String log_name = "jellyfish_merge.log"
    String sample_name
    Array[File?] jellyfish_input
    String jellyfish_output_name = "~{sample_name}.jf"
    String pb_conda_image

    Int threads = 4
  }

#  Float multiplier = 3.25
#  Int disk_size = ceil(multiplier * size(jellyfish_input, "GB")) + 20
  Int disk_size = 500

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate jellyfish
    echo "$(conda info)"

    (jellyfish merge -o ~{jellyfish_output_name} ~{sep=" " jellyfish_input}) > ~{log_name} 2>&1
  >>>
  output {
    File jellyfish_output = "~{jellyfish_output_name}"
    File log = "~{log_name}"
 }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "100 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

workflow jellyfish {
  input {
    String sample_name
    Array[File?] jellyfish_input
    String pb_conda_image
  }

  call jellyfish_merge {
    input:
      sample_name = sample_name,
      jellyfish_input = jellyfish_input,
      pb_conda_image = pb_conda_image
  }

  output {
    File? jellyfish_output = jellyfish_merge.jellyfish_output
    File? log = jellyfish_merge.log
  }
}
