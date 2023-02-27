version 1.0

import "tasks/deepvariant_round1.wdl" as deepvariant_round1
import "tasks/deepvariant_round2.wdl" as deepvariant_round2
import "tasks/whatshap_round1.wdl" as whatshap_round1
import "../common/structs.wdl"

workflow deepvariant {
  input {
    String sample_name
    Array[IndexedData] sample
    File regions_file
    IndexedData reference

    String pb_conda_image
    String deepvariant_image

  }

 Array[String] regions = read_lines(regions_file)  

 call deepvariant_round1.deepvariant_round1 {
    input:
      sample_name = sample_name,
      sample = sample,
      reference = reference,

      deepvariant_image = deepvariant_image
  }

 call whatshap_round1.whatshap_round1 {
    input:
      deepvariant_vcf_gz = deepvariant_round1.postprocess_variants_round1_vcf,
      reference = reference,
      sample_name = sample_name,
      sample = sample,
      regions = regions,
      pb_conda_image = pb_conda_image
  }

  call deepvariant_round2.deepvariant_round2 {
    input:
      reference = reference,
      sample_name = sample_name,
      whatshap_bams = whatshap_round1.whatshap_bams,
      deepvariant_image = deepvariant_image,
      pb_conda_image = pb_conda_image
  }

  output {
    IndexedData gvcf = deepvariant_round2.gvcf
  }

}
