version 1.0

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/reference/tasks/clinvar.wdl" as clinvar
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/reference/tasks/ensembl.wdl" as ensembl
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/reference/tasks/lof.wdl" as lof

workflow cohort {
    input {
        
        String pb_conda_image
        
        File gff
        File lof_lookup
        File clinvar_lookup
    }

    call clinvar.generate_clinvar_lookup {
        input:
            url = clinvar_lookup,
            pb_conda_image = pb_conda_image
    }

    call ensembl.reformat_ensembl_gff {
        input:
            url = gff,
            pb_conda_image = pb_conda_image
    }

    call lof.generate_lof_lookup {
        input:
            url = lof_lookup,
            pb_conda_image = pb_conda_image
    }

    output {
        File clinvar    = generate_clinvar_lookup.clinvar_lookup
        File gff        = slivar.filt_vcf
        File lof        = generate_lof_lookup.lof_lookup
    }
}