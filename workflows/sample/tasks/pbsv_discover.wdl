version 1.0

import "../../common/structs.wdl"


task pbsv_discover {
  input {
    String region
    String loglevel = "INFO"
    String log_name = "pbsv_discover.log"
    String extra_args = "--hifi"

    IndexedData smrtcell
    String? reference_name
    File tr_bed

    String svsig_gv_name = "~{smrtcell.name}.~{reference_name}.~{region}.svsig.gz"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(smrtcell.datafile, "GB") + size(smrtcell.indexfile, "GB") + size(tr_bed, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate pbsv
    echo "$(conda info)"

    (pbsv discover ~{extra_args}\
        --log-level ~{loglevel} \
        --region ~{region} \
        --tandem-repeats ~{tr_bed} \
        ~{smrtcell.datafile} ~{svsig_gv_name}) > ~{log_name} 2>&1
  >>>
  output {
    File svsig_gv = "~{svsig_gv_name}"
    File log = "~{log_name}"
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

workflow pbsv_discover_by_smartcells_output {
  input {
    String region
    Array[IndexedData] sample
    String? reference_name
    File tr_bed
    String pb_conda_image
  }

  scatter(smrtcell in sample) {
    call pbsv_discover {
      input:
        region = region,
        smrtcell = smrtcell,
        reference_name = reference_name,
        tr_bed = tr_bed,
        pb_conda_image = pb_conda_image
    }
  }

  output {
    Array[File] discover_svsig_gv = pbsv_discover.svsig_gv
  }
}
