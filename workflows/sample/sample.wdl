version 1.0

import "./tasks/common.wdl" as common
import "./tasks/pbsv.wdl" as pbsv
import "./tasks/deepvariant.wdl" as deepvariant
import "./tasks/deepvariant_round2.wdl" as deepvariant_round2
import "./tasks/check_kmer_consistency.wdl" as check_kmer_consistency
import "./tasks/jellyfish.wdl" as jellyfish
import "./tasks/mosdepth.wdl" as mosdepth
import "./tasks/sample_hifiasm.wdl" as sample_hifiasm
import "./tasks/whatshap.wdl" as whatshap
import "./tasks/whatshap_round2.wdl" as whatshap_round2


workflow sample {
  input {
    String md5sum_name

    SampleInfo sample
    Array[String] regions
    File tr_bed
    IndexedData reference

    File chr_lengths
    Array[File] jellyfish_input
    File ref_modimers
    File movie_modimers

    String pb_conda_image
    String deepvariant_image
    String picard_image
  }

  call pbsv.pbsv {
    input:
      regions = regions,
      sample = sample,
      tr_bed = tr_bed,
      reference = reference,

      pb_conda_image = pb_conda_image
  }

  call deepvariant.deepvariant {
    input:
      sample = sample,
      reference = reference,
      
      deepvariant_image = deepvariant_image
  }

 call whatshap.whatshap {
    input:
      deepvariant_vcf_gz = deepvariant.postprocess_variants_round1_vcf,
      reference = reference,
      sample = sample,
      regions = regions,
      pb_conda_image = pb_conda_image
  }

  call deepvariant_round2.deepvariant_round2 {
    input:
      reference = reference,
      sample_name = sample.name,
      whatshap_bams = whatshap.whatshap_bams,
      deepvariant_image = deepvariant_image,
      pb_conda_image = pb_conda_image
  }

 call whatshap_round2.whatshap_round2 {
    input:
      deepvariant_vcf_gz = deepvariant_round2.vcf,
      reference = reference,
      sample = sample,
      chr_lengths = chr_lengths,
      regions = regions,
      pb_conda_image = pb_conda_image,
      picard_image = picard_image
  }

  call mosdepth.mosdepth {
    input:
      sample_name = sample.name,
      bam_pair = whatshap_round2.deepvariant_haplotagged,
      reference_name = reference.name,
      pb_conda_image = pb_conda_image
  }

  call jellyfish.jellyfish_merge {
    input:
      sample_name = sample.name,
      jellyfish_input = jellyfish_input,
      pb_conda_image = pb_conda_image
  }

#  call check_kmer_consistency.check_kmer_consistency {
#    input:
#      ref_modimers = ref_modimers, 
#      movie_modimers = movie_modimers,
#      pb_conda_image = pb_conda_image
#  }

    call sample_hifiasm.sample_hifiasm {
      input:
        sample = sample,
        target = reference,
        pb_conda_image = pb_conda_image
    }

  output {
    IndexedData gvcf = deepvariant_round2.gvcf
    Array[Array[File]] svsig_gv = pbsv.svsig_gv
    IndexedData deepvariant_phased_vcf_gz = whatshap_bcftools_concat_round2.deepvariant_phased_vcf_gz
  }

}
