version 1.0

import "./tasks/clinvar.wdl" as clinvar
import "./tasks/ensembl.wdl" as ensembl
import "./tasks/lof.wdl" as lof

#import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/reference/tasks/clinvar.wdl" as clinvar_lookup
#import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/reference/tasks/ensembl.wdl" as ensembl
#import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/reference/tasks/lof.wdl" as lof

workflow cohort {
    input {
        
        String pb_conda_image
        
        File gff
        File lof
        File clinvar
    }

    call clinvar.generate_clinvar_lookup {
        input:
            url = clinvar,
            pb_conda_image = pb_conda_image
    }

    call ensembl.reformat_ensembl_gff {
        input:
            url = gff,
            pb_conda_image = pb_conda_image
    }

    call lof.generate_lof_lookup {
        input:
            url = lof,
            pb_conda_image = pb_conda_image
    }

    output {
        File clinvar_lookup                = generate_clinvar_lookup.clinvar_lookup
        File gff_reformatted               = reformat_ensembl_gff.ensembl_gff
        File lof_lookup                    = generate_lof_lookup.lof_lookup
    }
}
