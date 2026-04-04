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
    * Ligand: [**retinol (vitamin A)**](https://pubchem.ncbi.nlm.nih.gov/compound/445354)

      ```smiles
      CC1=C(C(CCC1)(C)C)/C=C/C(=C/C=C/C(=C/CO)/C)/C
      ```
    * Family: **Lipocalin** family;
    * Length: 201 aa (amino acids); MW: ~21 kDa;
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
  * Including sequence in [`fasta` format](https://rest.uniprot.org/uniprotkb/P02753.fasta) and [`pdb` structure with ligand](https://www.rcsb.org/structure/1RBP); click to view web source;
    > Note that the [`fasta` file](./Source%20Data/RBP4.seq.fasta) is the whole sequence with signaling peptide, while the downloaded [`pdb` file](./Source%20Data/RBP4.str.pdb) is the mature structure without; the [prediction structure file](./Results/Predict/RBP4_str_predict/seed_2802/predictions/RBP4_str_predict_sample_0.cif) generated in [T2](#t2) is derived from the downloaded whole sequence, making it an immature structure.
  * Check [`fasta` file](./Source%20Data/RBP4.seq.fasta) here.

    ```fasta
    >sp|P02753|RET4_HUMAN Retinol-binding protein 4 OS=Homo sapiens OX=9606 GN=RBP4 PE=1 SV=3
    MKWVWALLLLAALGSGRAERDCRVSSFRVKENFDKARFSGTWYAMAKKDPEGLFLQDNIV
    AEFSVDETGQMSATAKGRVRLLNNWDVCADMVGTFTDTEDPAKFKMKYWGVASFLQKGND
    DHWIVDTDYDTYAVQYSCRLLNLDGTCADSYSFVFSRDPNGLPPEAQKIVRQRQEELCLA
    RQYRLIVHNGYCDGRSERNLL
    ```
---
### T2
> Protein structure prediction.
* Run prediction on [ProteinX server](https://protenix-server.com/);
  * Submit the following sequence and set default parameters;

    ```
    MKWVWALLLLAALGSGRAERDCRVSSFRVKENFDKARFSGTWYAMAKKDPEGLFLQDNIVAEFSVDETGQMSATAKRVRLLNNWDVCADMVGTFTDTEDPAKFKMKYWGVASFLQKGNDDHWIVDTDYDTYAVQYSCRLLNLDGTCADSYSFFSRDPNGLPPEAQKIVRQRQEELCLARQYRLIVHNGYCDGRSERNLL
    ```
  * Results are in folder [Predict](./Results/Predict/) under folder [Results](./Results/);
  * Later analysis are mostly based on this `cif` file: [RBP4_str_predict_sample_0.cif](./Results/Predict/RBP4_str_predict/seed_2802/predictions/RBP4_str_predict_sample_0.cif).
* Operate on `cif` file with ChimeraX

    ```bash
    # 1. Open file
    open <path_to_cif_file> format mmcif

    # 2. Set basic display arguments
    set bgColor white
    color #1 #366d47ff
    lighting simple

    # 3. Highlight variant sites: 73A and 75A
    select :73,75
    show sel atoms
    style sel ball
    color sel #8B6508

    # 4. Create labels
    label :73 text A73T
    label :75 text A75T
    label height 1.5
    label color #ffd87e

    # 5. Save figure
    select clear
    save <path_to_png_file> width 3000 height 2000 supersample 3
    ```
* Acquire figures
  * Fig.1a shows the overall view of the protein, with the α-helix on the left being the unsevered signaling peptide;
![fig1a](./Processed/Predict/RBP4.pred.mut.1.png)
  * Fig.1b shows the overall view of the protein excluding the signaling peptide and highlighting the β-barrel;
![fig1b](./Processed/Predict/RBP4.pred.mut.2.png)
  * Fig.1c shows the detailed image of the mutation sites inside the β-barrel.
![fig1c](./Processed/Predict/RBP4.pred.mut.3.png)
---
### T3
> Identify most promising binding pocket.
* Preparation;
  * In the last `chimera` session (from [T2](#t2)), we may use the following command to convert the [`cif` file](./Results/Predict/RBP4_str_predict/seed_2802/predictions/RBP4_str_predict_sample_0.cif) to a [`pdb` file](./Results/Pocket/RBP4.str.predict.pdb); this step is for convenience in later analysis.

    ```bash
    save <path_to_pdb_file> format pdb models #1
    ```
* Predict promising binding pockets in `linux`;
  * If you are unfamiliar with operating in `linux` for bioinformatic analysis, watch [this teaching video](https://b23.tv/xMzD6oO) in bilibili to get a quick start;
    * We first need to install `miniconda3` and `mamba`;

      ```bash
      # Change to your working directory
      $ cd <your_working_dir>

      # Install miniconda3
      $ wget -c https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh
      $ bash Miniconda3-latest-Linux-x86_64.sh
      $ source ~/.bashrc
      # If you don't have wget, use apt or yum command lines to install wget

      # Install mamba
      $ conda install -n base mamba -c conda-forge -y
      ```
    * Then we need to move the [`pdb` file](./Results/Pocket/RBP4.str.predict.pdb) to our working directory.
  * Install and run `fpocket` for pocket prediction;

    ```bash
    # Install fpocket
    $ mamba install -c conda-forge fpocket

    # Run fpocket
    $ fpocket -f RBP4.str.predict.pdb
    # Aftercompletion, the results are stored in a directory called RBP4.str.predict_out.
    ```
  * View [results](./Results/Pocket/RBP4.str.predict_out/).
    * Under this folder, there are 2 files that are important;

      [RBP4.str.predict_out](./Results/Pocket/RBP4.str.predict_out/)
      ├── [RBP4.str.predict_info.txt](./Results/Pocket/RBP4.str.predict_out/RBP4.str.predict_info.txt)
      └── [pockets](./Results/Pocket/RBP4.str.predict_out/pockets/)
          └── [pocket1_atm.pdb](./Results/Pocket/RBP4.str.predict_out/pockets/pocket1_atm.pdb)
    * [RBP4.str.predict_info.txt](./Results/Pocket/RBP4.str.predict_out/RBP4.str.predict_info.txt) is a table that lists the credibility (score) of each predicted pocket;
    * [pocket1_atm.pdb](./Results/Pocket/RBP4.str.predict_out/pockets/pocket1_atm.pdb) is a `pdb` file that depicts all atoms predicted to form the most possible pocket among all.
* Visualization in ChimeraX.
  * Pipeline;
    * Open files and set basic outlook;

      ```bash
      # Open files
      open <path_to_cif_file> format mmcif
      open <path_to_atm.pdb_file>

      # Set background and basic settings
      set bgColor white
      color #1 #366d47ff
      lighting simple

      hide #2.1 models
      select #2
      color sel byatom
      style sel ball
      ```
    * Visualize pocket;

      ```bash
      # We can show the surface of atoms to visualize the pocket
      show sel surface
      color #2.2 #7cbbbeff
      transparency 70
      ```
    * Determine pocket residues and highlight them;

      ```bash
      # We can determine pocket residues by setting a distance threshold, like 3.5 Å
      select #1 & #2 :<3.5

      # Save information on the pocket residues for later analysis as txt file
      info residues sel saveFile <path_to_txt_file>

      # Highlight selected residues
      show sel atoms
      color sel byatom

      select #1 & ~sel
      color sel lightgrey
      transparency sel 90 target ac
      ```
    * Record spin movies and save figures;
    * Show mutation sites reletive to the pocket.

      ```bash
      # Modify certain outlook
      select #2
      color sel lightgrey target a

      # Highlight mutation sites
      select #1:73,75
      color sel #8B6508

      label :73@ca text A73T
      label :75@ca text A75T
      label height 1.5
      label color #ffd87e
      ```

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