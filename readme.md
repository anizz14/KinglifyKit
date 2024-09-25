## Example



########################## initialization   ###################
import SwiftUI
import KinglifyKit

@main
struct KinglifyInAppApp: App {
       
    @StateObject var kinglifyStoreKit = KinglifyStore(
        prodIds:["pookie.pro.monthly","pookie.pro.yearly"]

    );
    

    var body: some Scene {
        WindowGroup {
            KinglifyAppWrapper(
                content: ContentView(),
                handler: kinglifyStoreKit
            )
            .environmentObject(kinglifyStoreKit)
            
            
    }
}
}

            
#################### usages ############
            
            
  

import SwiftUI
import StoreKit
import KinglifyKit


// Main PaywallView struct
struct PaywallView: View {
    @EnvironmentObject var storeViewModel: KinglifyStore
    @State var monthlyPro: Product?
    @State var yearlyPro: Product?
//    @State var isLoading = true
    @State var selectedSubscription: SubscriptionType = .yearly
    @State private var isSheetPresented: Bool = false
//    @State var subscriptions : [Product] = []
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    


    var body: some View {
        ZStack {
            Color("CustomBlue")  // Use your custom color

            ScrollView {
              
                VStack(spacing: 0) {
//                    ZStack {
//                        PaywallTopGradient()
//                        RestoreButton()
//                        BackButton()  // Custom back button for navigation control
//                    }

                    VStack {
                        
                        if(storeViewModel.isLoading){
                            Text("Loading...")
                        }else{
                            ProductListView(yearlyPro: yearlyPro, monthlyPro: monthlyPro, selectedSubscription: $selectedSubscription)
                        }
                       
                           
                       

                        PaywallFeatures(title:"Phase-Specific Content", text: "Gain insights into her phases and moods to support her better.")
                        PaywallFeatures(title:"Pregnancy Probability", text: "Stay informed about fertility windows with detailed information on pregnancy probability, helping you plan for the future.")
                        PaywallFeatures(title:"Mood Insights", text: "Understand your wife’s mood variations throughout her cycle with mood insights, allowing for better emotional support and connection.")
                        PaywallFeatures(title:"Future Updates", text: "Access all future updates and enhancements as soon as they are released.")
                    }
                    .padding()
                    .padding(.top, 150)
                    .padding(.bottom, 60)
                    .frame(maxWidth: .infinity)
                    .background(Color("PrimaryBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .offset(y: -40)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
            }
            
            .refreshable {
                loadProducts()
            }
            .foregroundColor(Color("PrimaryText"))
            .overlay(
                VStack {
                    Spacer()
                    SubscribeButton(isSheetPresented: $isSheetPresented, monthlyPro: monthlyPro, yearlyPro: yearlyPro, selectedSubscription: selectedSubscription)
                        .padding()
                }
            )
        }
        
        .navigationBarBackButtonHidden()
        .edgesIgnoringSafeArea(.top)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSheetPresented) {
            FinalPaywall(isSheetPresented: $isSheetPresented, product: selectedSubscription == .monthly ? monthlyPro : yearlyPro)
//                .presentationDetents([.fraction(0.8)])

        }
        .onAppear {
            loadProducts()
        }
        .onChange(of: networkMonitor.isConnected) { _ in
            loadProducts()
        }
        .onChange(of:storeViewModel.subscriptions){_ in
            
            loadProducts()
        }
    }

    // Load products function
    func loadProducts() {
     
       
            //       isLoading = true
//                     subscriptions = storeViewModel.subscriptions
    
        for subscription in storeViewModel.subscriptions {
                        if subscription.id == "pookie.pro.monthly" {
                            self.monthlyPro = subscription
                           
                        } else if subscription.id == "pookie.pro.yearly" {
                            self.yearlyPro = subscription
                           
                        }
                    }

            
        
     
    }
}


enum SubscriptionType: String, CaseIterable {
    case monthly = "Monthly"
    case yearly = "Yearly"
}

struct RestoreButton: View {
    @EnvironmentObject var storeViewModel: KinglifyStore
    var body: some View{
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    // Your action here
                    Task {
                                        await storeViewModel.restorePurchases()
                                    }
                 
                    print("Button tapped")
                }) {
                    Text("Restore")
                        .padding()
                        .padding(.horizontal, 0)
                        .contentShape(Rectangle()) // Ensure the entire padding area is tappable
                }
                
            }
            
            Spacer()
            
        }
        .padding(.top, 60)
        .padding(.horizontal, 0)
    }
}

struct BackButton: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode> //for navigation back button to dismiss
    var body: some View{
        VStack {
            HStack {
              
                Button(action: {
                    // Your action here
                    presentationMode.wrappedValue.dismiss()

                }) {
                    HStack{
                        Image(systemName: "chevron.backward")
                        Text("Back")
                    }
               
                        .padding()
                        .padding(.horizontal, 0)
                        .contentShape(Rectangle()) // Ensure the entire padding area is tappable
                }
                Spacer()
            }
            
            Spacer()
            
        }
        .padding(.top, 60)
        .padding(.horizontal, 0)
    }
}


struct PaywallTopGradient: View {
    var body: some View {
        ZStack {
                 // Linear Gradient Background
                 LinearGradient(gradient: Gradient(colors: [Color("CustomBlue"), Color.purple]),
                                startPoint: .top,
                                endPoint: .bottom)
                 .frame(height: 400)
                     
                 
                 VStack {
                     // Circular Image
                     Image("peaceful") // Replace "yourImageName" with the name of your image asset
                         .resizable()
                         .aspectRatio(contentMode: .fill)
                         .frame(width: 150, height: 150)
                         .clipShape(Circle())
                         .overlay(Circle().stroke(Color.white, lineWidth: 4))
                         .shadow(radius: 10)
                     
                     // Text Below Image
                     Text("Understand her more")
                         .font(.title)
                         .fontWeight(.bold)
                         .foregroundColor(.white)
                         .padding(.top, 20)
                     Text("With daily updates")
                         .padding(6)
                         .background(
                                     RoundedRectangle(cornerRadius: 10)
                                         .stroke(Color.white, lineWidth: 1)
                                 )
                 }
             }
    }
}
//Price select option

struct PaywallPriceOptions: View {
    @EnvironmentObject var storeViewModel: KinglifyStore
    var product: Product
    let weeksPerMonth = 4.345
    let weeksPerYear = Decimal(52)
    var selectedOption: SubscriptionType
    var subscriptionType : SubscriptionType
    var body: some View{
        VStack{
           
            Text(subscriptionType == .yearly ? "BEST VALUE" : " ")
                .font(.caption)
                .bold()
        VStack(spacing: 0){
            ZStack{
            
                VStack {
                    if subscriptionType == .yearly {
                        
                        Text("12")
                            .font(.title)
                            .bold()
                        Text("Months")
                            }
                    else if subscriptionType == .monthly {
                        Text("1")
                            .font(.title)
                            .bold()
                        Text("Month")
                                    }
                                }
                .padding()
                .frame(width: 120)
                .background(Color("PrimaryText"))
                .foregroundStyle(Color("PrimaryBackground"))
            
                if selectedOption == subscriptionType {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title)
                        .offset(x:40, y: -22)
                }
            }
           
            ZStack{
                if subscriptionType == .yearly{
                    Text("Save 53%")
                        .padding(.horizontal)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green)
                        )
                        .foregroundColor(.white)
                        .offset(y: -30)
                        .font(.caption)
                }
                VStack(spacing:0){
                    if subscriptionType == .yearly {
                        Text(storeViewModel.monthlyPriceText(product: product, numberOfMonths: Decimal(12)))
                        
                            .font(.title2)
                            .bold()
                            .padding(.top,6)
                    }
                    if subscriptionType == .monthly {
                        Text(storeViewModel.monthlyPriceText(product: product, numberOfMonths: Decimal(1)))
                            
                            .font(.title2)
                            .bold()
                            .padding(.top,6)
                    }
                   
                     
                    Text("per month")
                        .font(.caption)
                    
                }
            }
           
            .padding(.vertical,4)
            .frame(width: 120)
            .background(Color("SecondaryText"))
            .foregroundStyle(Color("PrimaryBackground"))
            
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
       
        .overlay(
            Group{
            if selectedOption == subscriptionType {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 4)
            }
            }
        )
            Text(subscriptionType == .yearly ? "7-days free trial" : " ")
                .font(.footnote)
//                .bold()
        }
        
    }
    
    //Logic to get weekly price from product
    func weeklyPriceText(product: Product, numberOfWeeks: Decimal) -> String {
        let weeklyPrice = product.price / numberOfWeeks // Calculate weekly price
        let currencySymbol = getCurrencySymbol(from: product.displayPrice) // Extract currency symbol from display price
        return formatPrice(weeklyPrice, with: currencySymbol) // Format price with the extracted currency symbol
    }
//Logic to get currency from display price and format price.
    func formatPrice(_ price: Decimal, with currencySymbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol // Use the extracted currency symbol
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: price as NSDecimalNumber) ?? ""
    }

    func getCurrencySymbol(from displayPrice: String) -> String {
        let symbols = CharacterSet(charactersIn: "0123456789.-")
        return displayPrice.trimmingCharacters(in: symbols) // This assumes currency symbol is not mixed with numbers
    }
}



struct PaywallFeatures: View {
    var title: String
    var text: String
    var body: some View {
        HStack{
            Image(systemName: "checkmark.circle")
                .font(.title)
                .padding(.horizontal)
            VStack(alignment: .leading){
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(text)
                    .foregroundStyle(Color("SecondaryText"))
                    .font(.footnote)
            }
            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 4)
    }
}




//#Preview {
//    PaywallView().environmentObject(StoreViewModel())
//}

            
            
            
                       
                           
               
                
               
