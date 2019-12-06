#! /usr/bin/env python


# compHomogTest.py: a script to perform compositional homogeneity test using both simulation and Chi-squared test.
# Please type python compHomogTest.py -h to see the usage.
# Author: Sishuo Wang (sishuowang@hotmail.ca)

# Version: 1.2
# Last Updated: 2019-03-24
# default rateModel wag => lg
# Version: 1.1
# Last updated: 2018-02-02
# Updates:
#   1. t.optLogLike() will not be performed when the parameters are determined by RAxML. 


#####################################################################
import sys
import getopt
import commands
import re
import os
import glob
import StringIO

from p4 import *

#import rateModelConversion


#####################################################################
global raxml_prog, tree_tmp_dir, iqtree_prog, prottest_prog
raxml_prog = "/home-user/software/RAxML/latest/raxmlHPC-PTHREADS-SSE3" 
tree_tmp_dir = './tmp/'
iqtree_prog = 'iqtree'
prottest_prog = os.path.expanduser('~/software/phylo/prottest-3.4.2/prottest-3.4.2.jar')


#####################################################################
infiles = {'tree':None, 'data':None}
nSims = 100
isOptLog = False


#####################################################################
class ModelArgu(object):
    def __init__(self):
        self.invar_prop = 0.2
        self.compModel = 'empirical'
        self.compIsFree = False
        self.rateModel = 'lg'
        self.rateIsFree = False
        self.gamma = 0.8
        self.gammaIsFree = False
        self.is_tree_model = False
        self.propIsFree = False
        self.is_prottest_model = False
        #self.seqType = 'protein'

    def getModel(self, raxmlModel):
        rateModel_p4_to_raxml_rela = {
            'LG':'lg', 
            'JTT':'jtt',
            'WAG':'wag',
            'Dayhoff':'d78',
            'mtREV':'mtREV24',
            'RtREV':'rtRev',
            'CpREV':'cpREV',
            'Blosum62':'blosum62',
            'MtMam':'mtmam',
            'MtZoa':'mtzoa',
            'HIVb':'hivb',
            'StmtREV':'stmtREV',
        }

        rv = 'wag'
        for k, v in rateModel_p4_to_raxml_rela.iteritems():
            if re.search(raxmlModel, k, re.IGNORECASE):
                rv = rateModel_p4_to_raxml_rela[k]
                break
        self.ratemodel = rv



class ConstructTree(object):
    def __init__(self):
        pass


#####################################################################
def getParamsFromRaxml(infile, modelArgu):
    in_fh = open(infile, "r")
    for line in in_fh.readlines():
        line = line.rstrip('\n\r')
        m = re.search("^alpha\[0\]\:[ ]+(.+)$", line)
        if m:
            modelArgu.gamma = float(m.group(1))
        m = re.search("best-scoring AA model: (\w+) likelihood", line)
        if m:
            rateModel = m.group(1)
            modelArgu.getModel(rateModel)
    in_fh.close()
    return(modelArgu)


def getParamsFromIqtree(infile, modelArgu):
    in_fh = open(infile, "r")
    for line in in_fh.readlines():
        line = line.rstrip('\n\r')
        m = re.search("Gamma shape alpha: (\d+)$", line)
        if m:
            modelArgu.gamma = float(m.group(1))
        m = re.search("Proportion of invariable sites: (\d+)", line)
        if m:
            modelArgu.invar_prop = float(m.group(1))
    in_fh.close()
    return(modelArgu)


def runRaxml(aln_file, outdir, is_force=True):
    if not os.path.exists(outdir):
        os.mkdir(outdir)
    #else:
    #    for fname in glob.glob(outdir + "/*"):
    #        os.system("rm " + fname)
    c = getCorename(aln_file)
    info_file = os.path.join(outdir, 'RAxML_info.'+c)
    if os.path.exists(info_file):
        return
        #errorMessage("%s %s %s" % ("Fatal error! The file ", info_file, "has already existed!"))
    cmd = "%s %s %s %s %s %s" % (raxml_prog, '-f d -m PROTGAMMAAUTO -n', getCorename(aln_file), '-s', aln_file, '-p 123 -T 2 -w $PWD/'+outdir)
    status, output = commands.getstatusoutput(cmd)
    if status != 0:
        errorMessage("Fatal error! RAxML has encountered serious problems! Exiting ......")


def runIqtree(aln_file, outdir, modelArgu, is_force=False):
    if not os.path.exists(outdir):
        os.mkdir(outdir)
    #else:
    #    for fname in glob.glob(outdir + "/*"):
    #        os.system("rm " + fname)
    c = getCorename(aln_file)
    log_file = os.path.join(outdir, c+'.log')
    if os.path.exists(log_file):
        return
    if modelArgu.seqType == 'protein':
        cmd = "%s %s %s %s %s" % (iqtree_prog, '-s', aln_file, '-st AA -m LG+G+I -redo -nt AUTO -pre', os.path.join(outdir, c))
    elif modelArgu.seqType == 'DNA':
        cmd = "%s %s %s %s %s" % (iqtree_prog, '-s', aln_file, '-st DNA -m GTR+G+I -redo -nt AUTO -pre', os.path.join(outdir, c))
    status, output = commands.getstatusoutput(cmd)
    if status != 0:
        errorMessage("Fatal error! IQ-Tree has encountered serious problems! Exiting ......")


def do_prottest(aln_file, outdir):
    c = getCorename(aln_file)
    outfile = os.path.join(outdir, c+'.prottest')
    if os.path.exists(outfile):
        return(outfile)
    cmd = "%s %s %s %s %s %s %s" % ("java -jar", prottest_prog, "-i", aln_file, "-IG -F -LG", '>', outfile)
    status, output = commands.getstatusoutput(cmd)
    if status != 0:
        errorMessage("Fatal error! ProtTest has encountered serious problems! Exiting ......")
    else:
        return(outfile)


def getParamsFromProttest(infile, modelArgu):
    modelArgu.gammaIsFree = False # gammaIsFree set to False
    modelArgu.propIsFree = False # PropIsFree set to False
    with open(infile, 'r') as in_fh:
        for line in in_fh:
            line = line.rstrip('\n\r')
            m = re.search('gamma shape \(.+ rate categories\).. = (.+)$', line)
            if m:
                modelArgu.gamma = float(m.group(1))
            m = re.search('proportion of invariable sites... = (.+)$', line)
            if m:
                modelArgu.invar_prop = float(m.group(1))
    in_fh.close
    return(modelArgu)


def read_infiles(infiles, constructTree, modelArgu):
    read(infiles['data'])
    c = getCorename(infiles['data'])
    d = Data()

    var.alignments[0].checkForDuplicateSequences(removeDupes=False)

    if hasattr(constructTree, 'method'):
        if constructTree.method == 'bionj':
            status, output = commands.getstatusoutput('which ' + constructTree.method)
            if status != 0:
                errorMessage("%s %s %s %s" % ('Sorry! The method to construct the tree used in simulation', constructTree.method, 'is not available.', 'Exiting ......\n'))
            else:
                dm = var.alignments[0].pDistances()
                t = dm.bionj()
            if modelArgu.is_prottest_model:
                prottest_outfile = do_prottest(infiles['data'], tree_tmp_dir)
                modelArgu = getParamsFromProttest(prottest_outfile, modelArgu)

        elif re.search('^raxml$', constructTree.method, re.IGNORECASE):
            if not hasattr(modelArgu, 'seqType'):
                errorMessage("Fatal error! Sequence type need to be specified by '--seqType'")
            elif re.search('^DNA$', modelArgu.seqType, re.IGNORECASE):
                errorMessage("Fatal error! Sequence type cannot be DNA if using raxml to estimate parameters. Exiting ......")
            elif re.search('^protein$', modelArgu.seqType, re.IGNORECASE):
                runRaxml(infiles['data'], tree_tmp_dir) # run RAxML
                read(os.path.join(tree_tmp_dir, 'RAxML_bestTree.'+c))
                t = var.trees[0]
                if modelArgu.is_tree_model:
                    raxml_info_outfile = os.path.join(tree_tmp_dir, 'RAxML_info.'+c)
                    modelArgu = getParamsFromRaxml(raxml_info_outfile, modelArgu)
                    modelArgu.gammaIsFree = False # gammaIsFree set to False
                elif modelArgu.is_prottest_model:
                    prottest_outfile = do_prottest(infiles['data'], tree_tmp_dir)
                    modelArgu = getParamsFromProttest(prottest_outfile, modelArgu)
            else:
                errorMessage("Fatal error! Type has to be either 'DNA' or 'protein'. Exiting ......")
        
        elif re.search('^iqtree$', constructTree.method, re.IGNORECASE): #IQ-Tree
            runIqtree(infiles['data'], tree_tmp_dir, modelArgu) # run IQ-Tree
            print os.path.join(tree_tmp_dir, c+'.treefile')
            read(os.path.join(tree_tmp_dir, c+'.treefile'))
            t = var.trees[0]
            if modelArgu.is_tree_model:
                iqtree_info_outfile = os.path.join(tree_tmp_dir, c + '.log')
                modelArgu = getParamsFromIqtree(iqtree_info_outfile, modelArgu)
                modelArgu.gammaIsFree = False # gammaIsFree set to False
                modelArgu.propIsFree = False # propIsFree set to False

        else:
            errorMessage("Sorry. Only bionj is supported in tree construction now. Alternatively, you need to provide a tree ('-t').")

    else:
        read(infiles['tree'])
        t = var.trees[0]

    return([t, d, modelArgu])


def examine_required_info(infiles, constructTree):
    for i in ['tree', 'data']:
        if i == 'tree' and constructTree:
            continue
        if not infiles[i] or not os.path.isfile(infiles[i]):
            errorMessage("%s %s" % (i, "has to be specified. Exiting ......"))
            sys.exit(1)


def outputFinalResults(pipe, savedStdout):
    stdout_value = pipe.getvalue()
    sys.stdout = savedStdout
    pvalues = {}

    for i in stdout_value.split('\n'):
        m = re.search('^\s+All Sequences\s+(.+)$', i)
        if m:
            pvalues['sim'] = float(m.group(1))
        m = re.search('^\s+\(Chi-Squared Prob\)\s+\((.+)\)', i)
        if m:
            pvalues['chi2'] = float(m.group(1))

    print "# Output"
    for type, pvalue in pvalues.iteritems():
        print "\t".join((type, str(pvalue)))


def show_help():
    print "compHomogTest: a simple script to test compositional homogeneity using both simulation and Chi-squared test implemented in p4."
    print "Please make sure that p4 is installed before using. You may also want to install RAxML and/or bionj if you need to build trees using them."
    print "Please note that their references may need to be properly cited."
    print
    print "python", sys.argv[0], '<-d|--data datafile>';
    print "Note that either a nexus-formatted tree needs to be provided by -t or the tree has to be constructed by the method specified by -c"
    print 
    print "Optional arguments:"
    print "%-30s%s" % ('[-t|--tree=]', 'tree_file')
    print '%-30s%s' % ("[-c=|--constructTree=]", 'The method of tree construction used in simulation: bionj, raxml (Off)')
    print 
    print '%-30s%s' % ("[--invar_prop=]", 'Proportion of invariable sites (0.0)')
    print '%-30s%s' % ("[--nSims=]", 'No. of simulations (100)')
    print '%-30s%s' % ("[--gamma=]", 'Shape parameter of Gamma distribution (Off)')
    print '%-30s%s' % ("[--gammaFree|--gammaIsFree]", 'Shape parameter of Gamma distribution is set to free (No).')
    print '%-30s%s' % ("[--compFree|--compIsFree]", 'Compositional frequencies are set to be unfixed (No).')
    print '%-30s%s' % ("[--compModel=]", "Substitution model: 'equal', 'empirical', 'specified', 'cpREV', 'd78', 'jtt', 'mtREV24', 'mtmam', 'wag', 'rtRev', 'tmjtt94', 'tmlg99', 'lg', 'blosum62', 'hivb', 'mtart', 'mtzoa', 'gcpREV', 'stmtREV' (empirical)")
    print '%-30s%s' % ("[--rateFree|--rateIsFree]", 'Substitution rates are set to be variable (No).')
    print '%-30s%s' % ("[--rateModel=]", "Substitution model: 'ones', '2p', 'specified', 'optimized', 'cpREV', 'd78', 'jtt', 'mtREV24', 'mtmam', 'wag', 'rtRev', 'tmjtt94', 'tmlg99', 'lg', 'blosum62', 'hivb', 'mtart', 'mtzoa', 'gcpREV', 'stmtREV' (wag)")
    print '%-30s%s' % ("[--is_tree_model|--is_tree_model|--tree_model|--raxmlModel]", "")
    print '%-30s%s' % ("[--optLog]", "to perform tree.optLog()? (Off)")
    print '%-30s%s' % ("[--prottest|--ProtTest]", "to use parameters estimated by prottest? (Off)")
    print '%-30s%s' % ("", 'Whether to use RAxML to estimate the shape parameter and model. "wag" will be chosen if the best-fit model estimated by RAxML is not included in p4 (No).')
    print '%-30s%s' % ("[--tree_tmp_dir=]", 'Outdir for RAxML|IQ-Tree (tmp)')
    print '%-30s%s' % ("[--type=|--seqType=|--seq_type=]", '')
    print '%-30s%s' % ("", 'Sequence type: protein, DNA. Must be speficied in order to run RAxML to estimate the model (Off).')
    print '%-30s%s' % ("[-h|--h|--help]", 'Help message')
    print
    print '%-30s%s' % ('Author', 'Sishuo Wang @ Luo Haiwei Lab, Chinese University of Hong Kong. Please do not hesitate to write to sishuowang@hotmail.ca or sishuowang@cuhk.edu.hk for any bug report or suggestion. Your help is highly appreciated.')
    print '%-30s%s' % ('License', 'BSD-3-Clause (https://opensource.org/licenses/BSD-3-Clause)')
    print '\n'
    sys.exit()


def errorMessage(msg):
    print >> sys.stderr, msg
    sys.exit(1)


def getCorename(infile):
    b = os.path.basename(infile)
    c = None
    if re.search('\.', b):
        m = re.search('^(.+)(\.[^.]+)$', b)
        c = m.group(1)
    else:
        c = b
    return(c)


#####################################################################
status, output = commands.getstatusoutput("%s %s %s" % ('[ -x', raxml_prog, ']'))
if status != 0:
    errorMessage("raxmlHPC-PTHREADS-SSE3 cannot be found. Please specify the path to the executable file of RAxML by directyly modifying this script (at the beginning). Sorry for the inconvenience. Exiting ......")


modelArgu = ModelArgu()
constructTree = ConstructTree()


try:
    opts, args = getopt.getopt(sys.argv[1:], 't:d:c:h', ['data=', 'tree=', 'invar_prop=', 'nSims=', 'constructTree=',
        'gammaFree', 'gammaIsFree', 'gamma=',
        'compFree', 'compIsFree', 'compModel=',
        'rateFree', 'rateIsFree', 'rateModel=',
        'propIsFree',
        'free',
        'is_tree_model', 'is_tree_model', 'tree_model', 'raxmlModel', 'raxml_tmp_dir=', 'iqtree_tmp_dir=', 'tree_tmp_dir=',
        'type=', 'seqType=', 'seq_type=',
        'optLog', 'prottest', 'ProtTest',
        'help',],
    )
except getopt.GetoptError:
    print "Illegal params!"
    print
    show_help()

if not opts:
    show_help()

for opt, value in opts:
    if opt == '-t' or opt == '--tree':
        infiles['tree'] = value
    elif opt == '-d' or opt == '--data':
        infiles['data'] = value
    elif opt == '--gamma':
        modelArgu.gamma = float(value)
    elif opt == '--gammaFree':
        modelArgu.gammaIsFree = True
    elif opt == '--invar_prop':
        modelArgu.invar_proFp = float(value)
    elif opt == '--propFree':
        modelArgu.propIsFree = True
    elif opt == '--compFree' or opt == '--compIsFree':
        modelArgu.compIsFree = True
    elif opt == '--compModel':
        modelArgu.compModel = value
    elif opt == '--rateFree' or opt == '--rateIsFree':
        modelArgu.rateIsFree = True
    elif opt == '--rateModel':
        modelArgu.rateModel = value
    elif opt == '--free':
        modelArgu.compIsFree = True
        #modelArgu.rateIsFree = True
        modelArgu.gammaIsFree = True
        modelArgu.propIsFree = True
    elif opt in ['--is_tree_model', '--is_tree_model', '--tree_model', '--raxmlModel']:
        modelArgu.is_tree_model = True
    elif opt in ['--raxml_tmp_dir', '--iqtree_tmp_dir', '--tree_tmp_dir']:
        tree_tmp_dir = value
    elif opt == '--type' or opt == '--seqType' or opt == '--seq_type':
        modelArgu.seqType = value
    elif opt == '--nSims':
        nSims = int(value)
    elif opt == '-c' or opt == '--constructTree':
        constructTree.method = value
    elif opt == '--optLog':
        isOptLog = True
    elif opt == '--prottest' or opt == '--ProtTest':
        modelArgu.is_prottest_model = True
    elif opt == '-h' or opt == '--h' or opt == '--help':
        show_help()
    else:
        print >> sys.stderr, "Wrong argument " + opt + 'Exiting ......'
        show_help()


examine_required_info(infiles, constructTree)


#####################################################################
savedStdout = sys.stdout # save stdout
pipe = StringIO.StringIO()
sys.stdout = pipe


#####################################################################
t, d, modelArgu = read_infiles(infiles, constructTree, modelArgu)


# Attach the data and a model to the tree.
t.data = d
t.newComp(free=modelArgu.compIsFree, spec=modelArgu.compModel)
t.newRMatrix(free=modelArgu.rateIsFree, spec=modelArgu.rateModel)
t.setPInvar(free=modelArgu.propIsFree, val=modelArgu.invar_prop)

if hasattr(modelArgu, 'gamma') or modelArgu.gammaIsFree:
    t.setNGammaCat(nGammaCat=4) # No. of GammaCat is set to 4.
    t.newGdasrv(free=modelArgu.gammaIsFree, val=modelArgu.gamma)

# heterogeneous model
# t.setModelThingsRandomly()

# optimize
if (not modelArgu.is_tree_model and not modelArgu.is_prottest_model) or isOptLog:
    t.optLogLike()

# Run
t.compoTestUsingSimulations(nSims=nSims, doIndividualSequences=0, doChiSquare=True, verbose=1)

# output final results
outputFinalResults(pipe, savedStdout)

#print modelArgu.gamma, modelArgu.invar_prop


