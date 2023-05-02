version 1.0

import "tasks/pbsv.wdl" as pbsv
import "../common/structs.wdl"

workflow pbsv_single {
  input {
    String sample_name
    Array[IndexedData] sample
    File regions_file
    IndexedData reference

    File tr_bed

    String pb_conda_image

  }

  Array[String] regions = read_lines(regions_file)

  call pbsv.pbsv {
    input:
      sample_name = sample_name,
      sample = sample,
      reference = reference,
      regions = regions,
      tr_bed = tr_bed,

      pb_conda_image = pb_conda_image
  }

  output {
    File pbsv_vcf    = pbsv.pbsv_vcf
    Array[IndexedData] pbsv_individual_vcf    = pbsv.pbsv_individual_vcf
    Array[Array[File]] svsig_gv = pbsv.svsig_gv
  }

}
