package org.cipango.plugin;

import java.io.File;
import java.util.List;

import org.cipango.sipapp.SipAppContext;
import org.mortbay.jetty.plus.webapp.EnvConfiguration;
import org.mortbay.jetty.webapp.Configuration;
import org.mortbay.jetty.webapp.JettyWebXmlConfiguration;
import org.mortbay.jetty.webapp.TagLibConfiguration;
import org.mortbay.jetty.webapp.WebInfConfiguration;
import org.mortbay.jetty.webapp.WebXmlConfiguration;
import org.mortbay.util.LazyList;

public class CipangoPluginSipAppContext extends SipAppContext
{

    private List<File> classpathFiles;
    private File jettyEnvXmlFile;
    private File webXmlFile;
    private boolean annotationsEnabled = true;
    private EnvConfiguration envConfig =  new EnvConfiguration();
    private CipangoMavenConfiguration mvnConfig = new CipangoMavenConfiguration();

    private Configuration[] configs = 
    	new Configuration[]{
    		new WebInfConfiguration(),
    		envConfig, 
    		new WebXmlConfiguration(), 
    		mvnConfig,  
    		new JettyWebXmlConfiguration(), 
    		new TagLibConfiguration()};
    
    public CipangoPluginSipAppContext()
    {
        super();
        setConfigurations(configs);
    }
    
    public void addConfiguration(Configuration configuration)
    {
    	 if (isRunning())
             throw new IllegalStateException("Running");
    	 configs = (Configuration[]) LazyList.addToArray(configs, configuration, Configuration.class);
    	 setConfigurations(configs);
    }

    
    public void setClassPathFiles(List<File> classpathFiles)
    {
        this.classpathFiles = classpathFiles;
    }

    public List<File> getClassPathFiles()
    {
        return this.classpathFiles;
    }
    
    public void setWebXmlFile(File webXmlFile)
    {
        this.webXmlFile = webXmlFile;
    }
    
    public File getWebXmlFile()
    {
        return this.webXmlFile;
    }
    
    public void setJettyEnvXmlFile (File jettyEnvXmlFile)
    {
        this.jettyEnvXmlFile = jettyEnvXmlFile;
    }
    
    public File getJettyEnvXmlFile()
    {
        return this.jettyEnvXmlFile;
    }
    
    @SuppressWarnings("deprecation")
	public void configure ()
    {        
        setConfigurations(configs);
        mvnConfig.setClassPathConfiguration (classpathFiles);
 
        try
        {
            if (this.jettyEnvXmlFile != null)
                envConfig.setJettyEnvXml(this.jettyEnvXmlFile.toURL());
        }
        catch (Exception e)
        {
            throw new RuntimeException(e);
        }
    }


    public void doStart () throws Exception
    {
        setShutdown(false);
        super.doStart();
    }
     
    public void doStop () throws Exception
    {
        setShutdown(true);
        //just wait a little while to ensure no requests are still being processed
        Thread.sleep(500L);
        super.doStop();
    }

	public boolean isAnnotationsEnabled()
	{
		return annotationsEnabled;
	}

	public void setAnnotationsEnabled(boolean annotationsEnabled)
	{
		this.annotationsEnabled = annotationsEnabled;
	}
}