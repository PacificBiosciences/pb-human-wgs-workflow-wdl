version 1.0

task jellyfish_merge {
  input {
    String log_name = "jellyfish_merge.log"
    String sample_name
    Array[File] jellyfish_input
    String jellyfish_output_name = "~{sample_name}.jf"
    String pb_conda_image

    Int threads = 4
  }

  command <<<
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
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

