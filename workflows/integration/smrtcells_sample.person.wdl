version 1.0

#import "../smrtcells/smrtcells.person.wdl"
#import "../sample/sample.person.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/smrtcells/smrtcells.person.wdl"
import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/sample/sample.wdl"
import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/common/structs.wdl"

workflow smrtcells_sample_person {
  input {
    IndexedData reference
    Array[String] regions
    SampleInfo sample
    Int kmer_length

    File tr_bed
    File chr_lengths

    String pb_conda_image
    String deepvariant_image
    String picard_image
  }

  call smrtcells.person.smrtcells_person  {
    input :
      reference = reference,
      sample_name = sample.name,
      smrtcell_info = smrtcell_info,
      kmer_length = kmer_length,

      pb_conda_image = pb_conda_image
  }

  call sample.sample {
    input:
      sample_name = sample.name,
      sample = smrtcells_person.bams,
      jellyfish_input = smrtcells.count_jf,
      regions = regions,
      reference = reference,

      tr_bed = tr_bed,
      chr_lengths = ch_length,

      pb_conda_image = pb_conda_image,
      deepvariant_image = deepvariant_image,
      picard_image = picard_image
  }

  output {
    Array[IndexedData] bams     = smrtcells_person.bam
    Array[File] jellyfish_count = smrtcells_person.count_jf

    IndexedData gvcf = sample.gvcf
    Array[Array[File]] svsig_gv = sample.svsig_gv
    IndexedData deepvariant_phased_vcf_gz = sample.deepvariant_phased_vcf_gz
  }
}