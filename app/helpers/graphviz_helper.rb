require 'kconv'

module GraphvizHelper

  include InfoHelper
  
  def dot_line(name, options = {})
    line = name.to_s + " "
    unless options.empty?
      optstrs = options.map {|key, val|
        "#{key} = #{val}"
      }
      line += " [#{optstrs.join(', ')}]"
    end
    line += ';'
  end

  def dot_line_connect(a, b, isboth=false)
    opts = {}
    opts['dir'] = 'both'	if isboth
    dot_line("#{a} -> #{b}", opts)
  end
  
  def dot_digraph(name, &blk)
    str = "digraph #{name} {"
    str += yield 
    str += "}"
  end

  def quote(str)
    "\"#{str}\""
  end


  def create_dot_statuses(statuses, uses)
    opt = {}
    str = ""
    statuses.each {|sts|
      next 	unless uses.include?(sts.position)
      opt.clear
      if (sts.is_default?)
        opt['style'] = 'filled'
        opt['fillcolor'] = quote 'yellow'
      elsif (sts.is_closed?)
        opt['style'] = 'filled'
        opt['fillcolor'] = quote '#D3D3D3'
      end
      opt['label'] = quote sts.name
      str += dot_line(sts.position, opt)
    }
    str
  end


  def create_dot_workflow(statuses, wf, subwf)
    str = ""
    uses = []
    for stspos in 0..(statuses.size-1)
      for nstspos in (stspos+1)..(statuses.size-1)
        fore = workflow_flowable?(statuses[stspos], statuses[nstspos], wf, subwf)
        back = workflow_flowable?(statuses[nstspos], statuses[stspos], wf, subwf)
        if (fore)
          str += dot_line_connect(statuses[stspos].position, statuses[nstspos].position, back)
        elsif (back)
          str += dot_line_connect(statuses[nstspos].position, statuses[stspos].position)
        end
        if (fore or back)
          uses << statuses[stspos].position
          uses << statuses[nstspos].position
        end
      end
    end
    [str, uses.uniq]
  end


  def create_dot_digraph_workflow(graphname, statuses, wf, subwf)
    dot_digraph(quote graphname) {
      str = "ranksep = 0.3;"
      opt = {'shape' => 'box', 'margin' => '0.05'}
      str += dot_line('node', opt)
      struses = create_dot_workflow(statuses, wf, subwf)
      str += create_dot_statuses(statuses, struses.last)
      str += struses.first
    }
  end


  def exec_dot(src)
    dest = ""
    errstr = ""
    reststr = ""
    bgnptn = /^<svg/
    endptn = /^<\/svg>/
    errptn = /^Error/i
    warningptn = /^\(dot(\.exe)?:\d+\)/i
    dotcmd = Setting.plugin_redmine_information[:dot_cmdpath]
    dotcmd = 'dot'	if (!dotcmd.kind_of?(String) or dotcmd.empty?)
    begin
      IO.popen("\"#{dotcmd}\" -Tsvg 2>&1", 'r+') {|io|
        io.puts src
        io.close_write
        while (str = io.gets)
          if (errptn =~ str)
            errstr << str
          elsif (warningptn =~ str)
            errstr << str
          elsif (bgnptn)
            if (bgnptn =~ str)
              dest += str
              bgnptn = nil
            else
              reststr << str
            end
          elsif (!bgnptn and endptn)
            dest += str
            endptn = nil	if (endptn =~ str)
          else
            reststr << str
          end
        end
      }
    rescue => evar
      errstr << l(:text_err_dot) + "\n"
      errstr << Kconv.toutf8(evar.to_s)
    end
    if (dest.empty? or !$?.exited? or $?.exitstatus != 0)
      errstr = l(:text_err_dot) + "\n" + Kconv.toutf8(errstr)
      errstr << Kconv.toutf8(reststr)
    end
    {:svg=>dest, :err=>errstr}
  end
  
  def create_workflow_chart(graphname, statuses, wf, subwf)
    results = exec_dot(create_dot_digraph_workflow(graphname, statuses, wf, subwf))
    output = results[:svg]
    unless (results[:err].blank?)
      output += "<div class='nodata'> #{simple_format(results[:err])}</div>"
    end
    output
  end
  
end
