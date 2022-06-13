version 1.0

#import "./tasks/common.wdl" as common
#import "./tasks/pbsv.wdl" as pbsv
#import "./tasks/deepvariant_round1.wdl" as deepvariant_round1
#import "./tasks/deepvariant_round2.wdl" as deepvariant_round2
#import "./tasks/jellyfish.wdl" as jellyfish
#import "./tasks/mosdepth.wdl" as mosdepth
#import "./tasks/hifiasm.wdl" as hifiasm
#import "./tasks/whatshap_round1.wdl" as whatshap_round1
#import "./tasks/whatshap_round2.wdl" as whatshap_round2
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/common.wdl" as common
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/pbsv.wdl" as pbsv
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/deepvariant_round1.wdl" as deepvariant_round1
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/deepvariant_round2.wdl" as deepvariant_round2
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/jellyfish.wdl" as jellyfish
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/mosdepth.wdl" as mosdepth
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/hifiasm.wdl" as hifiasm
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/whatshap_round1.wdl" as whatshap_round1
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/whatshap_round2.wdl" as whatshap_round2
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/tandem_genotypes.wdl" as tandem_genotypes
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

workflow sample {
  input {
    String sample_name
    Array[IndexedData] sample
    Array[File?] jellyfish_input
    Array[String] regions
    IndexedData reference

    File tr_bed
    File chr_lengths

    File ref_modimers
    File movie_modimers

    String pb_conda_image
    String deepvariant_image
    String picard_image

    Boolean run_jellyfish

    File tg_list
    File tg_bed
    File score_matrix
    LastIndexedData last_reference

  }

  call pbsv.pbsv {
    input:
      sample_name = sample_name,
      sample = sample,
      reference = reference,
      regions = regions,
      tr_bed = tr_bed,

      pb_conda_image = pb_conda_image
  }

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

 call whatshap_round2.whatshap_round2 {
    input:
      deepvariant_vcf_gz = deepvariant_round2.vcf,
      reference = reference,
      sample_name = sample_name,
      sample = sample,
      regions = regions,
      chr_lengths = chr_lengths,
      pb_conda_image = pb_conda_image,
      picard_image = picard_image
  }

  call mosdepth.mosdepth {
    input:
      sample_name = sample_name,
      bam = whatshap_round2.deepvariant_haplotagged,
      reference_name = reference.name,
      pb_conda_image = pb_conda_image
  }

  if(run_jellyfish) {                                                       #only run jellyfish if run_jellyfish is true AND there are multiple jellyfish_input files
    if(length(jellyfish_input) > 1) {                                        #otherwise, if there is only one jellyfish_input file, then just pass jellyfish_input to final output
      call jellyfish.jellyfish {
        input:
          sample_name = sample_name,
          jellyfish_input = jellyfish_input,
          pb_conda_image = pb_conda_image
      }
    }
  }

  call tandem_genotypes.tandem_genotypes {
    input:
      sample_name = sample_name,
      pb_conda_image = pb_conda_image,
      tg_list = tg_list,
      score_matrix = score_matrix,
      tg_bed = tg_bed,
      last_reference = last_reference,
      haplotagged_bam = whatshap_round2.deepvariant_haplotagged.datafile,
      haplotagged_bai = whatshap_round2.deepvariant_haplotagged.indexfile,
  }

  call hifiasm.hifiasm {
    input:
      sample_name = sample_name,
      sample = sample,
      target = reference,
      reference_name = reference.name,
      pb_conda_image = pb_conda_image
  }

  output {
    IndexedData gvcf = deepvariant_round2.gvcf
    File pbsv_vcf    = pbsv.pbsv_vcf
    Array[IndexedData] pbsv_individual_vcf    = pbsv.pbsv_individual_vcf
    Array[Array[File]] svsig_gv = pbsv.svsig_gv
    IndexedData deepvariant_phased_vcf_gz = whatshap_round2.deepvariant_phased_vcf_gz

    File? jellyfish_output = jellyfish.jellyfish_output
    File? log = jellyfish.log

    File sample_tandem_genotypes = tandem_genotypes.sample_tandem_genotypes
    File sample_tandem_genotypes_absolute = tandem_genotypes.sample_tandem_genotypes_absolute
    File sample_tandem_genotypes_plot = tandem_genotypes.sample_tandem_genotypes_plot
    File sample_tandem_genotypes_dropouts = tandem_genotypes.sample_tandem_genotypes_dropouts

  }

}
