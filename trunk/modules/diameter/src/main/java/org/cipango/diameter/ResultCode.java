// ========================================================================
// Copyright 2008-2009 NEXCOM Systems
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

package org.cipango.diameter;

import org.cipango.diameter.base.Base;

public class ResultCode 
{
	private int _vendorId;
	private int _code;
	private String _name;
	
	public ResultCode(int vendorId, int code, String name)
	{
		_code = code;
		_name = name;
	}
	
	public int getCode()
	{
		return _code;
	}
	
	public String getName()
	{
		return _name;
	}
	
	public boolean isInformational()
	{
		return (_code / 1000) == 1;
	}
	
	public boolean isSuccess()
	{
		return (_code / 1000) == 2;
	}
	
	public boolean isProtocolError()
	{
		return (_code / 1000) == 3;
	}
	
	public boolean isTransientFailure()
	{
		return (_code / 1000) == 4;
	}
	
	public boolean isPermanentFailure()
	{
		return (_code / 1000) == 5;
	}
	
	public AVP<?> getAVP()
	{
		if (_vendorId == Base.IETF_VENDOR_ID)
			return new AVP<Integer>(Base.RESULT_CODE, _code);
		else
		{
			AVPList expRc = new AVPList();
			expRc.add(Base.EXPERIMENTAL_RESULT_CODE, _code);
			return new AVP<AVPList>(Base.EXPERIMENTAL_RESULT, expRc);
		}
	}
}
