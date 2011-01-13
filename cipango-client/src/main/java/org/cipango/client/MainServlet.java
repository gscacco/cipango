// ========================================================================
// Copyright 2011 NEXCOM Systems
// ------------------------------------------------------------------------
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at 
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// ========================================================================
package org.cipango.client;

import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.sip.SipServlet;
import javax.servlet.sip.SipServletRequest;
import javax.servlet.sip.SipServletResponse;

import org.eclipse.jetty.util.log.Log;

public class MainServlet extends SipServlet
{
	
	private CipangoClient _cipangoClient;
	
	public MainServlet(CipangoClient cipangoClient)
	{
		_cipangoClient = cipangoClient;
	}

	@Override
	protected void doRequest(SipServletRequest request) throws ServletException, IOException
	{
		Session session = (Session) request.getSession().getAttribute(SipSession.class.getName());
		if (session == null)
		{
			session = _cipangoClient.getUasSession();
			if (session == null)
			{
				Log.warn("Received initial request and there is no UAS session to handle it.\n" + request);
				request.createResponse(SipServletResponse.SC_SERVER_INTERNAL_ERROR, "No UAS session found");
				return;
			}
			session.setSipSession(request.getSession());
		}
		synchronized (session)
		{
			session.addSipRequest(new SipRequestImpl(request));
			session.notify();
		}
		
	}

	@Override
	protected void doResponse(SipServletResponse response) throws ServletException, IOException
	{
		SipServletRequest request = response.getRequest();

		SipRequestImpl sipRequest = (SipRequestImpl) request.getAttribute(SipMessage.class.getName());
		synchronized (sipRequest)
		{
			sipRequest.addSipResponse(new SipResponseImpl(response));
			
			sipRequest.notify();
		}
	}
	
}
