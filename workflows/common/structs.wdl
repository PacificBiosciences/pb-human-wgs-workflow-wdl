version 1.0

struct IndexedData {
  String? name
  File datafile
  File indexfile
}

struct LastIndexedData{
  String name
  File last_reference_bck
  File last_reference_des
  File last_reference_prj
  File last_reference_sds
  File last_reference_ssp
  File last_reference_suf
  File last_reference_tis
}

struct SmrtcellInfo {
  String name
  File path
  Boolean isUbam
}

struct SampleInfo {
  String name
  Array[String?] parents
  Array[SmrtcellInfo] smrtcells
}

struct CohortInfo {
  Array[SampleInfo] affected_persons
  Array[SampleInfo] unaffected_persons
}
