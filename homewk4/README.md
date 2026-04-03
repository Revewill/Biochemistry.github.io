# Homework 4

> An answer `md` file for homework 4 in course *Biochemistry* by 黄悉然.

> Quickly direct to [T1](#t1), [T2](#t2), [T3](#t3), [T4](#t4), [T5](#t5) or [T6](#t6).
---
### T1
> Select disease and protein of interest.
* **Selected disease and protein;**
  * Disease: [**MCOPCB10**](https://omim.org/entry/616428), autosomal dominant **microphthalmia/coloboma**-10 (MIM ID: [#616428](https://omim.org/entry/616428));
    * **MCOPCB10** is an **AD** genetic disease caused by mutations in the **RBP4** gene[^1];
    * Manifested as ocular developmental disorders including microphthalmia, anophthalmia, and/or coloboma[^2];
    * Caused by **heterozygous mutation** in [**RBP4** gene](https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/9922) (MIM ID: [180250](https://omim.org/entry/180250); HGNC ID: [9922](https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/9922); Ensembl ID: [ENSG00000138207](https://www.ensembl.org/Homo_sapiens/Gene/Summary?g=ENSG00000138207); UCSC ID: [uc003vng.3](http://genome.cse.ucsc.edu/cgi-bin/hgGene?org=Human&hgg_chrom=none&hgg_type=knownGene&hgg_gene=uc003vng.3))[^3].
      * **RBP4**, retinol binding protein 4;
      * Encodes protein **RBP4**, a key protein in MCOPCB10 pathology.
  * Protein: [**RBP4**](https://www.uniprot.org/uniprotkb/P02753/entry), retinol-binding protein 4 (UniProt ID: [P02753](https://www.uniprot.org/uniprotkb/P02753/entry)).
    * **RBP4**, *homo sapiens*, encoded by gene RBP4;
    * Function (see reference on [UniProt](https://www.uniprot.org/uniprotkb/P02753/entry));
      * Transports **retinol (vitamin A)** from **liver** to peripheral tissues, particularly to the **retina** for visual cycle maintenance;
        * Binds retinol with high affinity ($K_d \in (0.1,1) \text{nM}$) within its **hydrophobic β-barrel pocket**;
        * Another site of RBP4 binds to receptor **[STRA6](https://www.uniprot.org/uniprotkb/Q9BX79/entry)** to transfer retinol.
      * Due to the small size of RBP4, it binds with TTR to form a tetramer to prevent its loss through renal filtration;
      * Also relevant with Type II diabetes, obesity, etc.
    * Ligand: **retinol (vitamin A)**

      ```smiles
      CC1=C(C(CCC1)(C)C)C=CC(=CC=CC(=CCO)C)C
      ```
    * Family: **Lipocalin** family
    * Length: 201 aa (amino acids); MW: ~21 kDa
    * Pathology and variants[^4].
      * Pathological variants: [**A73T**](https://web.expasy.org/variant_pages/VAR_073856.html) and [**A75T**](https://web.expasy.org/variant_pages/VAR_073857.html);
      * Molecular pathology:
        * Site **73** and **75** are located in the **hydrophobic β-barrel pocket**, binding pocket of retinol;
        * These mutations from hydrophobic residues to hydrophilic ones are unfavorable for retinol binding and conformation stability;
        * As a result, the variants' binding efficiency with retinol is compromised, while the conformational changes increase their affinity with STRA6.
      * Physiological pathology
        * The mutated proteins prevail in competition with normal proteins to bind with receptor STRA6 yet deliver less retinol, making the mutation a dominant one;
        * Lack of retinol in eye tissues result in a disorder of eye formation.
* **Downloaded relevant data.**
  * All source data are stored in folder [**Source Data**](./Source%20Data/) under parent folder;

    [Source Data](./Source%20Data/)
    ├── [RBP4.seq.fasta](./Source%20Data/RBP4.seq.fasta)
    └── [RBP4.str.pdb](./Source%20Data/RBP4.str.pdb)
  * Including sequence in [`fasta` format](https://rest.uniprot.org/uniprotkb/P02753.fasta) and [`pdb` structure with ligand](https://www.rcsb.org/structure/1RBP); click to view web source.
---
### T2
> Protein structure prediction.

---
### T3
> Identify most promising bniding pocket.

---
### T4
> Perform virtual screening for ligand.

---
### T5
> Detailed interactions.

---
### T6
> Experimental strategies.

[^1]: [Williamson, K. A., et al. Mutations in RBP4 cause an autosomal dominant form of microphthalmia. *Am. J. Hum. Genet.* 105(3): 566-577, 2019.](https://doi.org/10.1016/j.ajhg.2019.07.010)
[^2]: [Verma, A., et al. Clinical spectrum of RBP4-related microphthalmia. *Ophthalmology*. 128(4): 612-619, 2021.](https://doi.org/10.1016/j.ophtha.2020.09.028)
[^3]: [Chou, C. M., et al. RBP4 retinol-binding protein. *Mol. Vis.* 26: 412-425, 2020.](https://doi.org/10.1007/s00412-020-00735-w)
[^4]: [Chou, C. M., et al. Biochemical basis for dominant inheritance, variable penetrance, and maternal effects in RBP4 congenital eye disease. *Cell.* 161(3): 634-646, 2015.](https://doi.org/10.1016/j.cell.2015.03.006)