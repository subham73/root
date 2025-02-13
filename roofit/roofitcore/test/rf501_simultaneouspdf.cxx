//////////////////////////////////////////////////////////////////////////
//
// 'ORGANIZATION AND SIMULTANEOUS FITS' RooFit tutorial macro #501
//
// Using simultaneous p.d.f.s to describe simultaneous fits to multiple
// datasets
//
//
//
// 07/2008 - Wouter Verkerke
//
/////////////////////////////////////////////////////////////////////////

#ifndef __CINT__
#include "RooGlobalFunc.h"
#endif
#include "RooRealVar.h"
#include "RooDataSet.h"
#include "RooGaussian.h"
#include "RooChebychev.h"
#include "RooAddPdf.h"
#include "RooSimultaneous.h"
#include "RooCategory.h"
#include "TCanvas.h"
#include "RooPlot.h"
using namespace RooFit ;


class TestBasic501 : public RooFitTestUnit
{
public:
  TestBasic501(TFile* refFile, bool writeRef, Int_t verbose) : RooFitTestUnit("Simultaneous p.d.f. operator",refFile,writeRef,verbose) {} ;
  bool testCode() {

  // C r e a t e   m o d e l   f o r   p h y s i c s   s a m p l e
  // -------------------------------------------------------------

  // Create observables
  RooRealVar x("x","x",-8,8) ;

  // Construct signal pdf
  RooRealVar mean("mean","mean",0,-8,8) ;
  RooRealVar sigma("sigma","sigma",0.3,0.1,10) ;
  RooGaussian gx("gx","gx",x,mean,sigma) ;

  // Construct background pdf
  RooRealVar a0("a0","a0",-0.1,-1,1) ;
  RooRealVar a1("a1","a1",0.004,-1,1) ;
  RooChebychev px("px","px",x,RooArgSet(a0,a1)) ;

  // Construct composite pdf
  RooRealVar f("f","f",0.2,0.,1.) ;
  RooAddPdf model("model","model",RooArgList(gx,px),f) ;



  // C r e a t e   m o d e l   f o r   c o n t r o l   s a m p l e
  // --------------------------------------------------------------

  // Construct signal pdf.
  // NOTE that sigma is shared with the signal sample model
  RooRealVar mean_ctl("mean_ctl","mean_ctl",-3,-8,8) ;
  RooGaussian gx_ctl("gx_ctl","gx_ctl",x,mean_ctl,sigma) ;

  // Construct the background pdf
  RooRealVar a0_ctl("a0_ctl","a0_ctl",-0.1,-1,1) ;
  RooRealVar a1_ctl("a1_ctl","a1_ctl",0.5,-0.1,1) ;
  RooChebychev px_ctl("px_ctl","px_ctl",x,RooArgSet(a0_ctl,a1_ctl)) ;

  // Construct the composite model
  RooRealVar f_ctl("f_ctl","f_ctl",0.5,0.,1.) ;
  RooAddPdf model_ctl("model_ctl","model_ctl",RooArgList(gx_ctl,px_ctl),f_ctl) ;



  // G e n e r a t e   e v e n t s   f o r   b o t h   s a m p l e s
  // ---------------------------------------------------------------

  // Generate 1000 events in x and y from model
  RooDataSet *data = model.generate(RooArgSet(x),100) ;
  RooDataSet *data_ctl = model_ctl.generate(RooArgSet(x),2000) ;



  // C r e a t e   i n d e x   c a t e g o r y   a n d   j o i n   s a m p l e s
  // ---------------------------------------------------------------------------

  // Define category to distinguish physics and control samples events
  RooCategory sample("sample","sample") ;
  sample.defineType("physics") ;
  sample.defineType("control") ;

  // Construct combined dataset in (x,sample)
  RooDataSet combData("combData","combined data",x,Index(sample),Import("physics",*data),Import("control",*data_ctl)) ;



  // C o n s t r u c t   a   s i m u l t a n e o u s   p d f   i n   ( x , s a m p l e )
  // -----------------------------------------------------------------------------------

  // Construct a simultaneous pdf using category sample as index
  RooSimultaneous simPdf("simPdf","simultaneous pdf",sample) ;

  // Associate model with the physics state and model_ctl with the control state
  simPdf.addPdf(model,"physics") ;
  simPdf.addPdf(model_ctl,"control") ;



  // P e r f o r m   a   s i m u l t a n e o u s   f i t
  // ---------------------------------------------------

  // Perform simultaneous fit of model to data and model_ctl to data_ctl
  simPdf.fitTo(combData) ;



  // P l o t   m o d e l   s l i c e s   o n   d a t a    s l i c e s
  // ----------------------------------------------------------------

  // Make a frame for the physics sample
  RooPlot* frame1 = x.frame(Bins(30),Title("Physics sample")) ;

  // Plot all data tagged as physics sample
  combData.plotOn(frame1,Cut("sample==sample::physics")) ;

  // Plot "physics" slice of simultaneous pdf.
  // NBL You _must_ project the sample index category with data using ProjWData
  // as a RooSimultaneous makes no prediction on the shape in the index category
  // and can thus not be integrated
  simPdf.plotOn(frame1,Slice(sample,"physics"),ProjWData(sample,combData)) ;
  simPdf.plotOn(frame1,Slice(sample,"physics"),Components("px"),ProjWData(sample,combData),LineStyle(kDashed)) ;

  // The same plot for the control sample slice
  RooPlot* frame2 = x.frame(Bins(30),Title("Control sample")) ;
  combData.plotOn(frame2,Cut("sample==sample::control")) ;
  simPdf.plotOn(frame2,Slice(sample,"control"),ProjWData(sample,combData)) ;
  simPdf.plotOn(frame2,Slice(sample,"control"),Components("px_ctl"),ProjWData(sample,combData),LineStyle(kDashed)) ;


  regPlot(frame1,"rf501_plot1") ;
  regPlot(frame2,"rf501_plot2") ;

  delete data ;
  delete data_ctl ;

  return true ;

  }

} ;
