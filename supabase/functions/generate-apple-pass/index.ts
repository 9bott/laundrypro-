import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('No auth header')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } =
      await supabase.auth.getUser(token)
    if (authError || !user) throw new Error('Unauthorized')

    const { data: customer, error: custError } = await supabase
      .from('customers')
      .select('*')
      .eq('auth_user_id', user.id)
      .single()
    if (custError || !customer) throw new Error('Customer not found')

    const PASSKIT_API_KEY = Deno.env.get('PASSKIT_API_KEY')!
    const PROGRAM_ID = Deno.env.get('PASSKIT_PROGRAM_ID')!

    const fullName = String(customer.name || 'Customer')
    const phone = String(customer.phone || '')
    const cashback = Number(customer.cashback_balance || 0)
    const subscription = Number(customer.subscription_balance || 0)
    const planAr = String(customer.active_plan_name_ar || '')

    // Create or update member in PassKit
    const memberPayload = {
      programId: PROGRAM_ID,
      externalId: customer.id,
      firstName: customer.name?.split(' ')[0] || customer.name || 'Customer',
      lastName: customer.name?.split(' ').slice(1).join(' ') || '',
      mobileNumber: phone,
      emailAddress: customer.email || '',
      points: Math.floor(cashback * 100),
      tier: planAr || customer.tier || 'bronze',
      metaData: [
        { key: 'customer_name', value: fullName },
        { key: 'phone', value: phone },
        { key: 'cashback_balance', value: cashback.toFixed(2) },
        { key: 'subscription_balance', value: subscription.toFixed(2) },
        { key: 'active_plan_name_ar', value: planAr },
      ],
    }

    // Try to create member first
    let memberResponse = await fetch(
      `https://api.passkit.net/v1/loyalty/member`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${btoa(PASSKIT_API_KEY + ':')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(memberPayload),
      }
    )

    // If member exists (409), update instead
    if (memberResponse.status === 409) {
      memberResponse = await fetch(
        `https://api.passkit.net/v1/loyalty/member/${customer.id}`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Basic ${btoa(PASSKIT_API_KEY + ':')}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(memberPayload),
        }
      )
    }

    const memberData = await memberResponse.json()

    // Get the pass download URL
    const passUrl = memberData?.passUrl ||
      `https://pub1.pskt.io/${memberData?.id || customer.id}`

    return new Response(
      JSON.stringify({
        success: true,
        pass_url: passUrl,
        member_id: memberData?.id,
        customer_name: customer.name,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    return new Response(
      JSON.stringify({ success: false, error: message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})

