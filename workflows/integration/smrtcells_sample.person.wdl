version 1.0

#import "../smrtcells/smrtcells.person.wdl"
#import "../sample/sample.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/smrtcells/smrtcells.person.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

workflow smrtcells_sample_person {
  input {
    IndexedData reference
    File regions_file
    SampleInfo sample_info
    Int kmer_length

    File tr_bed
    File chr_lengths

    String pb_conda_image
    String deepvariant_image
  }

  Array[String] regions = read_lines(regions_file)

  call smrtcells.person.smrtcells_person  {
    input :
        reference = reference,
        sample_info = sample_info,
        kmer_length = kmer_length,

        pb_conda_image = pb_conda_image
  }

  call sample.sample {
    input:
      sample_name = sample_info.name,
      sample = smrtcells_person.bams,
      jellyfish_input = smrtcells_person.jellyfish_count,
      regions = regions,
      reference = reference,

      tr_bed = tr_bed,
      chr_lengths = chr_lengths,

      pb_conda_image = pb_conda_image,
      deepvariant_image = deepvariant_image,
  }

  output {
    Array[IndexedData] bams     = smrtcells_person.bams
    Array[File] jellyfish_count = smrtcells_person.jellyfish_count

    IndexedData gvcf = sample.gvcf
    Array[Array[File]] svsig_gv = sample.svsig_gv
    IndexedData deepvariant_phased_vcf_gz = sample.deepvariant_phased_vcf_gz
  }
}
